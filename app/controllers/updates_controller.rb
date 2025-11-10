class UpdatesController < ApplicationController
  include Authenticatable

  def conversations_updates
    # Validate userId parameter
    unless params[:userId].present?
      render json: { error: "userId parameter is required" }, status: :bad_request
      return
    end

    # Validate userId matches current user
    unless params[:userId].to_s == @current_user.id.to_s
      render json: { error: "Unauthorized" }, status: :unauthorized
      return
    end

    # Check if user is acting as an expert (has assigned conversations)
    # Since all users have expert profiles, we check if they have any assigned conversations
    has_assigned_conversations = Conversation.where(assigned_expert_id: @current_user.id).exists?

    if @current_user.expert_profile && has_assigned_conversations
      # Experts can see: conversations they initiated, assigned to them, or waiting conversations
      initiated = Conversation.where(initiator_id: @current_user.id)
      assigned = Conversation.where(assigned_expert_id: @current_user.id)
      waiting = Conversation.where(status: "waiting", assigned_expert_id: nil)

      # Combine all three types
      conversation_ids = initiated.pluck(:id) + assigned.pluck(:id) + waiting.pluck(:id)
      conversations = Conversation.where(id: conversation_ids.uniq)
    else
      # Non-experts can only see conversations they initiated
      conversations = Conversation.where(initiator_id: @current_user.id)
    end

    # Filter by since timestamp if provided
    if params[:since].present?
      begin
        since_time = Time.parse(params[:since])
        conversations = conversations.where("updated_at > ?", since_time)
      rescue ArgumentError
        render json: { error: "Invalid timestamp format. Use ISO 8601 format." }, status: :bad_request
        return
      end
    end

    # Order by updated_at descending
    conversations = conversations.order(updated_at: :desc)

    render json: conversations.map { |conv| conversation_response(conv) }, status: :ok
  end

  def messages_updates
    # Validate userId parameter
    unless params[:userId].present?
      render json: { error: "userId parameter is required" }, status: :bad_request
      return
    end

    # Validate userId matches current user
    unless params[:userId].to_s == @current_user.id.to_s
      render json: { error: "Unauthorized" }, status: :unauthorized
      return
    end

    # Check if user is acting as an expert (has assigned conversations)
    # Since all users have expert profiles, we check if they have any assigned conversations
    has_assigned_conversations = Conversation.where(assigned_expert_id: @current_user.id).exists?

    if @current_user.expert_profile && has_assigned_conversations
      # Experts can see messages from: conversations they initiated, assigned to them, or waiting conversations
      # Experts can view messages from waiting conversations even before claiming them
      initiated = Conversation.where(initiator_id: @current_user.id)
      assigned = Conversation.where(assigned_expert_id: @current_user.id)
      waiting = Conversation.where(status: "waiting", assigned_expert_id: nil)

      user_conversation_ids = (initiated.pluck(:id) + assigned.pluck(:id) + waiting.pluck(:id)).uniq
    else
      # Non-experts can only see messages from conversations they initiated
      user_conversation_ids = Conversation.where(initiator_id: @current_user.id).pluck(:id)
    end

    # Return empty array if user has no accessible conversations
    if user_conversation_ids.empty?
      render json: [], status: :ok
      return
    end

    # Get messages only from conversations the user has access to
    # Use pluck to ensure we get the actual IDs, not a subquery that might have issues
    messages = Message.where(conversation_id: user_conversation_ids)

    # Filter by since timestamp if provided
    if params[:since].present?
      begin
        since_time = Time.parse(params[:since])
        messages = messages.where("created_at > ?", since_time)
      rescue ArgumentError
        render json: { error: "Invalid timestamp format. Use ISO 8601 format." }, status: :bad_request
        return
      end
    end

    # Order by created_at ascending
    messages = messages.order(created_at: :asc)

    # Double-check: filter out any messages from conversations the user doesn't have access to
    # This is an extra safety check in case of any edge cases
    filtered_messages = messages.select do |message|
      conversation = message.conversation
      if @current_user.expert_profile && has_assigned_conversations
        # Experts: initiator, assigned expert, or waiting conversations (can view before claiming)
        conversation && (
          conversation.initiator_id == @current_user.id ||
          (conversation.assigned_expert_id.present? && conversation.assigned_expert_id == @current_user.id) ||
          (conversation.status == "waiting" && conversation.assigned_expert_id.nil?)
        )
      else
        # Non-experts: only initiator
        conversation && conversation.initiator_id == @current_user.id
      end
    end

    render json: filtered_messages.map { |message| message_response(message) }, status: :ok
  end

  def expert_queue_updates
    # Validate expertId parameter
    unless params[:expertId].present?
      render json: { error: "expertId parameter is required" }, status: :bad_request
      return
    end

    # Ensure user has expert profile
    expert_profile = @current_user.expert_profile
    unless expert_profile
      render json: { error: "Expert profile required" }, status: :forbidden
      return
    end

    # Validate expertId matches current expert profile
    unless params[:expertId].to_s == expert_profile.id.to_s
      render json: { error: "Unauthorized" }, status: :unauthorized
      return
    end

    # Get waiting conversations (status: waiting, no assigned expert)
    waiting_conversations = Conversation.where(status: "waiting", assigned_expert_id: nil)

    # Get assigned conversations (where current expert is assigned)
    assigned_conversations = Conversation.where(assigned_expert_id: @current_user.id)

    # Filter by since timestamp if provided
    if params[:since].present?
      begin
        since_time = Time.parse(params[:since])
        waiting_conversations = waiting_conversations.where("updated_at > ?", since_time)
        assigned_conversations = assigned_conversations.where("updated_at > ?", since_time)
      rescue ArgumentError
        render json: { error: "Invalid timestamp format. Use ISO 8601 format." }, status: :bad_request
        return
      end
    end

    # Order conversations
    waiting_conversations = waiting_conversations.order(created_at: :asc)
    assigned_conversations = assigned_conversations.order(updated_at: :desc)

    # Response format: array with one object containing both arrays
    render json: [ {
      waitingConversations: waiting_conversations.map { |conv| conversation_response(conv) },
      assignedConversations: assigned_conversations.map { |conv| conversation_response(conv) }
    } ], status: :ok
  end

  private

  def conversation_response(conversation)
    {
      id: conversation.id.to_s,
      title: conversation.title,
      status: conversation.status,
      questionerId: conversation.initiator_id.to_s,
      questionerUsername: conversation.initiator.username,
      assignedExpertId: conversation.assigned_expert_id&.to_s,
      assignedExpertUsername: conversation.assigned_expert&.username,
      createdAt: conversation.created_at.iso8601,
      updatedAt: conversation.updated_at.iso8601,
      lastMessageAt: conversation.last_message_at&.iso8601,
      unreadCount: unread_count(conversation)
    }
  end

  def unread_count(conversation)
    # Count messages that are unread and not sent by the current user
    conversation.messages.where(is_read: false)
                .where.not(sender_id: @current_user.id)
                .count
  end

  def message_response(message)
    {
      id: message.id.to_s,
      conversationId: message.conversation_id.to_s,
      senderId: message.sender_id.to_s,
      senderUsername: message.sender.username,
      senderRole: sender_role(message),
      content: message.content,
      timestamp: message.created_at.iso8601,
      isRead: message.is_read
    }
  end

  def sender_role(message)
    if message.sender == message.conversation.initiator
      "initiator"
    elsif message.sender == message.conversation.assigned_expert
      "expert"
    else
      nil
    end
  end
end

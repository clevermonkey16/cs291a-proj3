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

    # Get conversations where user is initiator or assigned expert
    conversations = Conversation.where(
      "initiator_id = ? OR assigned_expert_id = ?",
      @current_user.id,
      @current_user.id
    )

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

    # Get conversations where user is initiator or assigned expert
    user_conversations = Conversation.where(
      "initiator_id = ? OR assigned_expert_id = ?",
      @current_user.id,
      @current_user.id
    )

    # Get messages from those conversations
    messages = Message.where(conversation_id: user_conversations.select(:id))

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

    render json: messages.map { |message| message_response(message) }, status: :ok
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
    render json: [{
      waitingConversations: waiting_conversations.map { |conv| conversation_response(conv) },
      assignedConversations: assigned_conversations.map { |conv| conversation_response(conv) }
    }], status: :ok
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


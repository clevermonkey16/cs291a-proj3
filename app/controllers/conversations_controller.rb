class ConversationsController < ApplicationController
  include Authenticatable

  def index
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
      conversations = Conversation.where(id: conversation_ids.uniq).order(updated_at: :desc)
    else
      # Non-experts can only see conversations they initiated
      conversations = Conversation.where(initiator_id: @current_user.id).order(updated_at: :desc)
    end

    render json: conversations.map { |conv| conversation_response(conv) }, status: :ok
  end

  def show
    conversation = Conversation.find_by(id: params[:id])

    # Check if conversation exists
    unless conversation
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    # Check if user has access to the conversation
    unless user_can_access_conversation?(conversation)
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    render json: conversation_response(conversation), status: :ok
  end

  def create
    conversation = Conversation.new(
      title: params[:title],
      initiator: @current_user,
      status: "waiting"
    )

    if conversation.save
      render json: conversation_response(conversation), status: :created
    else
      render json: { errors: conversation.errors.full_messages }, status: :unprocessable_entity
    end
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
end

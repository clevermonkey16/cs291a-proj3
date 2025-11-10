class ConversationsController < ApplicationController
  include Authenticatable

  def index
    # Get conversations where user is initiator or assigned expert
    conversations = Conversation.where(
      "initiator_id = ? OR assigned_expert_id = ?",
      @current_user.id,
      @current_user.id
    )
    
    # If user is an expert, also include waiting conversations
    if @current_user.expert_profile
      waiting_conversations = Conversation.where(status: "waiting", assigned_expert_id: nil)
      conversations = Conversation.where(
        "id IN (?) OR id IN (?)",
        conversations.select(:id),
        waiting_conversations.select(:id)
      )
    end
    
    # Order by updated_at descending
    conversations = conversations.order(updated_at: :desc)

    render json: conversations.map { |conv| conversation_response(conv) }, status: :ok
  end

  def show
    conversation = Conversation.find_by(id: params[:id])
    
    # Check if conversation exists and user has access
    unless conversation && user_can_access_conversation?(conversation)
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


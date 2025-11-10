class MessagesController < ApplicationController
  include Authenticatable

  def index
    conversation = Conversation.find_by(id: params[:conversation_id])
    
    # Check if conversation exists and user has access
    unless conversation && user_can_access_conversation?(conversation)
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    # Get all messages for the conversation, ordered by created_at
    messages = conversation.messages.order(created_at: :asc)
    
    render json: messages.map { |message| message_response(message) }, status: :ok
  end

  def create
    conversation = Conversation.find_by(id: params[:conversationId])
    
    # Check if conversation exists and user has access
    unless conversation && user_can_access_conversation?(conversation)
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    message = Message.new(
      conversation: conversation,
      sender: @current_user,
      content: params[:content]
    )

    if message.save
      # Update conversation's last_message_at
      conversation.update(last_message_at: message.created_at)
      
      render json: message_response(message), status: :created
    else
      render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def mark_read
    message = Message.find_by(id: params[:id])
    
    # Check if message exists
    unless message
      render json: { error: "Message not found" }, status: :not_found
      return
    end

    conversation = message.conversation
    
    # Check if user has access to the conversation
    unless user_can_access_conversation?(conversation)
      render json: { error: "Message not found" }, status: :not_found
      return
    end

    # Check if user is trying to mark their own message as read
    if message.sender_id == @current_user.id
      render json: { error: "Cannot mark your own messages as read" }, status: :forbidden
      return
    end

    # Mark message as read
    message.update(is_read: true)
    
    render json: { success: true }, status: :ok
  end

  private

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


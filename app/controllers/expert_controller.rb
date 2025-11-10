class ExpertController < ApplicationController
  include Authenticatable

  before_action :ensure_expert

  def queue
    # Get waiting conversations (status: waiting, no assigned expert)
    waiting_conversations = Conversation.where(status: "waiting", assigned_expert_id: nil)
                                       .order(created_at: :asc)
    
    # Get assigned conversations (where current expert is assigned)
    assigned_conversations = Conversation.where(assigned_expert_id: @current_user.id)
                                        .order(updated_at: :desc)
    
    render json: {
      waitingConversations: waiting_conversations.map { |conv| conversation_response(conv) },
      assignedConversations: assigned_conversations.map { |conv| conversation_response(conv) }
    }, status: :ok
  end

  def claim
    conversation = Conversation.find_by(id: params[:conversation_id])
    
    # Check if conversation exists
    unless conversation
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    # Check if conversation is already assigned to an expert
    if conversation.assigned_expert_id.present?
      render json: { error: "Conversation is already assigned to an expert" }, status: :unprocessable_entity
      return
    end

    # Assign conversation to current expert
    conversation.update(
      assigned_expert_id: @current_user.id,
      status: "active"
    )

    # Create expert assignment record
    ExpertAssignment.create!(
      conversation: conversation,
      expert: @current_user.expert_profile,
      status: "active",
      assigned_at: Time.current
    )

    render json: { success: true }, status: :ok
  end

  def unclaim
    conversation = Conversation.find_by(id: params[:conversation_id])
    
    # Check if conversation exists
    unless conversation
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end

    # Check if current user is assigned to this conversation
    unless conversation.assigned_expert_id == @current_user.id
      render json: { error: "You are not assigned to this conversation" }, status: :forbidden
      return
    end

    # Unassign conversation (return to waiting queue)
    conversation.update(
      assigned_expert_id: nil,
      status: "waiting"
    )

    # Update expert assignment record (mark as resolved)
    expert_assignment = ExpertAssignment.find_by(
      conversation: conversation,
      expert: @current_user.expert_profile,
      status: "active"
    )
    
    if expert_assignment
      expert_assignment.update(
        status: "resolved",
        resolved_at: Time.current
      )
    end

    render json: { success: true }, status: :ok
  end

  def profile
    expert_profile = @current_user.expert_profile
    
    render json: {
      id: expert_profile.id.to_s,
      userId: expert_profile.user_id.to_s,
      bio: expert_profile.bio,
      knowledgeBaseLinks: expert_profile.knowledge_base_links || [],
      createdAt: expert_profile.created_at.iso8601,
      updatedAt: expert_profile.updated_at.iso8601
    }, status: :ok
  end

  def update_profile
    expert_profile = @current_user.expert_profile
    
    if expert_profile.update(
      bio: params[:bio],
      knowledge_base_links: params[:knowledgeBaseLinks] || []
    )
      render json: {
        id: expert_profile.id.to_s,
        userId: expert_profile.user_id.to_s,
        bio: expert_profile.bio,
        knowledgeBaseLinks: expert_profile.knowledge_base_links || [],
        createdAt: expert_profile.created_at.iso8601,
        updatedAt: expert_profile.updated_at.iso8601
      }, status: :ok
    else
      render json: { errors: expert_profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def assignments_history
    expert_profile = @current_user.expert_profile
    
    # Get all expert assignments for this expert
    assignments = ExpertAssignment.where(expert: expert_profile)
                                  .order(assigned_at: :desc)
    
    render json: assignments.map { |assignment| assignment_response(assignment) }, status: :ok
  end

  private

  def ensure_expert
    unless @current_user.expert_profile
      render json: { error: "Expert profile required" }, status: :forbidden
    end
  end

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

  def assignment_response(assignment)
    {
      id: assignment.id.to_s,
      conversationId: assignment.conversation_id.to_s,
      expertId: assignment.expert_id.to_s,
      status: assignment.status,
      assignedAt: assignment.assigned_at.iso8601,
      resolvedAt: assignment.resolved_at&.iso8601,
      rating: assignment.rating
    }
  end
end


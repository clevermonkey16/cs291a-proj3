module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    @current_user = current_user
    unless @current_user
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def current_user
    # Try JWT token first
    token = extract_token_from_header
    if token
      decoded = JwtService.decode(token)
      return User.find_by(id: decoded[:user_id]) if decoded
    end

    # Fall back to session
    return nil unless session[:user_id]
    User.find_by(id: session[:user_id])
  end

  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header

    # Extract token from "Bearer <token>"
    match = auth_header.match(/^Bearer (.+)$/)
    match ? match[1] : nil
  end

  def user_can_access_conversation?(conversation)
    return false unless conversation
    
    # User is the initiator
    return true if conversation.initiator_id == @current_user.id
    
    # User is the assigned expert
    return true if conversation.assigned_expert_id == @current_user.id
    
    # User is an expert and conversation is in waiting queue
    if @current_user.expert_profile && conversation.status == "waiting" && conversation.assigned_expert_id.nil?
      return true
    end
    
    false
  end
end


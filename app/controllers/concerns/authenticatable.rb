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
    return false unless @current_user

    # User is the initiator
    if conversation.initiator_id.to_s == @current_user.id.to_s
      return true
    end

    # User is the assigned expert (only if assigned_expert_id is not nil)
    if conversation.assigned_expert_id.present? &&
       conversation.assigned_expert_id.to_s == @current_user.id.to_s
      return true
    end

    # User can access waiting conversations (unclaimed)
    # All users have expert profiles and can switch to expert mode
    if conversation.status == "waiting" &&
       conversation.assigned_expert_id.nil?
      return true
    end

    false
  end
end

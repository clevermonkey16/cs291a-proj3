class AuthController < ApplicationController
  def register
    user = User.new(username: params[:username], password: params[:password])

    if user.save
      # Update last_active_at
      user.update(last_active_at: Time.current)

      # Set session
      session[:user_id] = user.id

      # Generate JWT token
      token = JwtService.encode(user)

      render json: {
        user: user_response(user),
        token: token
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(username: params[:username])

    if user && user.authenticate(params[:password])
      # Update last_active_at
      user.update(last_active_at: Time.current)

      # Set session
      session[:user_id] = user.id

      # Generate JWT token
      token = JwtService.encode(user)

      render json: {
        user: user_response(user),
        token: token
      }, status: :ok
    else
      render json: { error: "Invalid username or password" }, status: :unauthorized
    end
  end

  def logout
    # Get the current session_id before resetting
    old_session_id = session.id rescue nil

    # Reset session - this clears data and creates a new session_id
    reset_session

    # Delete the old session record from the database
    if old_session_id
      ActiveRecord::SessionStore::Session.find_by(session_id: old_session_id)&.destroy
    end

    # Access the session to ensure the new empty session is created and persisted
    session.id

    render json: { message: "Logged out successfully" }, status: :ok
  end

  def refresh
    user = current_user_from_session

    if user
      # Update last_active_at
      user.update(last_active_at: Time.current)

      # Generate new JWT token
      token = JwtService.encode(user)

      render json: {
        user: user_response(user),
        token: token
      }, status: :ok
    else
      render json: { error: "No session found" }, status: :unauthorized
    end
  end

  def me
    user = current_user_from_session

    if user
      render json: user_response(user), status: :ok
    else
      render json: { error: "No session found" }, status: :unauthorized
    end
  end

  private

  def current_user_from_session
    return nil unless session[:user_id]
    User.find_by(id: session[:user_id])
  end

  def user_response(user)
    {
      id: user.id,
      username: user.username,
      created_at: user.created_at.iso8601,
      last_active_at: user.last_active_at&.iso8601
    }
  end
end

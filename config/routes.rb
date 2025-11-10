Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Health check endpoint
  get "health", to: "health#show"

  # Authentication endpoints
  post "auth/register", to: "auth#register"
  post "auth/login", to: "auth#login"
  post "auth/logout", to: "auth#logout"
  post "auth/refresh", to: "auth#refresh"
  get "auth/me", to: "auth#me"

  # Conversations endpoints
  get "conversations", to: "conversations#index"
  post "conversations", to: "conversations#create"

  # Messages endpoints (must come before conversations/:id to avoid route conflicts)
  get "conversations/:conversation_id/messages", to: "messages#index"

  # Conversations endpoints (continued)
  get "conversations/:id", to: "conversations#show"

  # Messages endpoints (continued)
  post "messages", to: "messages#create"
  put "messages/:id/read", to: "messages#mark_read"

  # Expert endpoints
  get "expert/queue", to: "expert#queue"
  get "expert/profile", to: "expert#profile"
  put "expert/profile", to: "expert#update_profile"
  get "expert/assignments/history", to: "expert#assignments_history"
  post "expert/conversations/:conversation_id/claim", to: "expert#claim"
  post "expert/conversations/:conversation_id/unclaim", to: "expert#unclaim"

  # Update/Polling endpoints
  get "api/conversations/updates", to: "updates#conversations_updates"
  get "api/messages/updates", to: "updates#messages_updates"
  get "api/expert-queue/updates", to: "updates#expert_queue_updates"

  # Defines the root path route ("/")
  # root "posts#index"
end

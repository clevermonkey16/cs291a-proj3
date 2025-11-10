class User < ApplicationRecord
  has_secure_password

  # Validations
  validates :username, presence: true, uniqueness: true, length: { minimum: 1, maximum: 255 }

  # Associations
  has_one :expert_profile, dependent: :destroy
  has_many :conversations, foreign_key: :initiator_id, class_name: "Conversation", dependent: :destroy
  has_many :messages, foreign_key: :sender_id, class_name: "Message", dependent: :destroy
  has_many :expert_assignments, foreign_key: :expert_id, class_name: "ExpertAssignment", dependent: :destroy

  # Callbacks
  after_create :create_expert_profile

  private

  def create_expert_profile
    ExpertProfile.create!(user: self, bio: "", knowledge_base_links: [])
  end
end

class Conversation < ApplicationRecord
  belongs_to :initiator, class_name: "User"
  belongs_to :assigned_expert, class_name: "User", optional: true
  has_many :messages, dependent: :destroy
  has_many :expert_assignments, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :status, inclusion: { in: %w[waiting active resolved] }
end

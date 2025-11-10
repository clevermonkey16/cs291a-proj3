class ExpertProfile < ApplicationRecord
  belongs_to :user
  has_many :expert_assignments, foreign_key: :expert_id, class_name: "ExpertAssignment", dependent: :destroy
end

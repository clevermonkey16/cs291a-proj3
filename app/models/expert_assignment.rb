class ExpertAssignment < ApplicationRecord
  belongs_to :conversation
  belongs_to :expert, class_name: "User"
end

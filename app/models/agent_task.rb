class AgentTask < ApplicationRecord
  belongs_to :conversation

  validates :title, presence: true
  validates :status, inclusion: { in: %w[pending in_progress completed failed] }
end

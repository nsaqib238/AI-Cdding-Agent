class CommandExecution < ApplicationRecord
  belongs_to :conversation

  validates :command, presence: true
  validates :status, inclusion: { in: %w[pending running completed failed] }
end

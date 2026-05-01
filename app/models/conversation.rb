class Conversation < ApplicationRecord
  belongs_to :project, class_name: 'CodingProject', optional: true
  has_many :messages, dependent: :destroy
  has_many :agent_tasks, dependent: :destroy
  has_many :command_executions, dependent: :destroy

  validates :title, presence: true
end

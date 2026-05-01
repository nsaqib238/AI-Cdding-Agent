class Message < ApplicationRecord
  include LlmMessageValidationConcern
  
  belongs_to :conversation

  validates :role, inclusion: { in: %w[user assistant system] }
end

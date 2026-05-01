require 'rails_helper'

RSpec.describe AiAgentService, type: :service do
  describe '#call' do
    it 'can be initialized and called' do
      conversation = create(:conversation)
      service = AiAgentService.new(
        conversation: conversation,
        prompt: "Test prompt",
        stream_name: "test_stream"
      )
      expect { service.call }.not_to raise_error
    end
  end
end

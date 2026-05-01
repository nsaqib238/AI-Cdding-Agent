class LlmStreamJob < ApplicationJob
  queue_as :llm

  # Retry strategy configuration
  retry_on Net::ReadTimeout, wait: 5.seconds, attempts: 3
  retry_on LlmService::TimeoutError, wait: 5.seconds, attempts: 3
  retry_on LlmService::ApiError, wait: 10.seconds, attempts: 2

  # Streaming LLM responses via ActionCable
  # Usage:
  #   LlmStreamJob.perform_later(stream_name: 'chat_123', prompt: "Hello")
  #   LlmStreamJob.perform_later(stream_name: 'chat_456', prompt: "...", tools: [...], conversation_id: 1)
  #
  # CRITICAL: ALL broadcasts MUST have 'type' field (auto-routes to client handler)
  # - type: 'chunk' → client calls handleChunk(data)
  # - type: 'complete' → client calls handleComplete(data)
  # - type: 'tool_call' → (optional) client calls handleToolCall(data)
  # - type: 'tool_result' → (optional) client calls handleToolResult(data)
  def perform(stream_name:, prompt:, system: nil, conversation_id: nil, **options)
    full_content = ""

    # If tools are provided and conversation_id is given, wrap with tool handler
    if options[:tools].present? && conversation_id.present?
      conversation = Conversation.find(conversation_id)
      agent_service = AiAgentService.new(conversation: conversation, prompt: prompt, stream_name: stream_name)
      
      options[:tool_handler] = ->(name, args) {
        # Broadcast tool call to UI
        ActionCable.server.broadcast(stream_name, {
          type: 'tool_call',
          tool_name: name,
          arguments: args
        })
        
        # Execute tool via agent service
        result = agent_service.send(:handle_tool_call, name, args)
        
        # Broadcast result to UI
        ActionCable.server.broadcast(stream_name, {
          type: 'tool_result',
          tool_name: name,
          result: result
        })
        
        result
      }
    end

    # Stream LLM response with chunk broadcasting
    LlmService.call(prompt: prompt, system: system, **options) do |chunk|
      full_content += chunk
      ActionCable.server.broadcast(stream_name, {
        type: 'chunk',
        chunk: chunk
      })
    end

    # Broadcast completion
    ActionCable.server.broadcast(stream_name, {
      type: 'complete',
      content: full_content
    })
  end
end

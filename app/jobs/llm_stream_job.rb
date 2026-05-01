class LlmStreamJob < ApplicationJob
  queue_as :llm

  # Retry strategy configuration
  retry_on Net::ReadTimeout, wait: 5.seconds, attempts: 3
  retry_on LlmService::TimeoutError, wait: 5.seconds, attempts: 3
  retry_on LlmService::ApiError, wait: 10.seconds, attempts: 2

  # Streaming LLM responses via ActionCable
  # Usage:
  #   LlmStreamJob.perform_later(stream_name: 'chat_123', prompt: "Hello")
  #   LlmStreamJob.perform_later(stream_name: 'chat_456', prompt: "...", tools: [...], tool_handler: ...)
  #
  # CRITICAL: ALL broadcasts MUST have 'type' field (auto-routes to client handler)
  # - type: 'chunk' → client calls handleChunk(data)
  # - type: 'complete' → client calls handleComplete(data)
  # - type: 'tool_call' → (optional) client calls handleToolCall(data)
  def perform(stream_name:, prompt:, system: nil, **options)
    full_content = ""

    # Wrap tool_handler to broadcast tool calls if provided
    if options[:tool_handler]
      original_handler = options[:tool_handler]
      options[:tool_handler] = ->(name, args) {
        ActionCable.server.broadcast(stream_name, {
          type: 'tool_call',
          tool_name: name,
          arguments: args
        })
        original_handler.call(name, args)
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

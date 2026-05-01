class ChatChannel < ApplicationCable::Channel
  def subscribed
    @stream_name = params[:stream_name]
    reject unless @stream_name

    stream_from @stream_name
  rescue StandardError => e
    handle_channel_error(e)
    reject
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  rescue StandardError => e
    handle_channel_error(e)
  end

  def send_message(data)
    conversation = Conversation.find(data['conversation_id'])
    
    # Save user message
    user_message = conversation.messages.create!(
      role: 'user',
      content: data['content']
    )

    # Broadcast user message immediately
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'user-message',
        id: user_message.id,
        content: user_message.content,
        timestamp: user_message.created_at.iso8601
      }
    )

    # Process AI response using agent service
    AiAgentService.call(
      conversation: conversation,
      prompt: data['content'],
      stream_name: @stream_name
    )
  rescue StandardError => e
    handle_channel_error(e)
    ActionCable.server.broadcast(
      @stream_name,
      {
        type: 'error',
        message: e.message
      }
    )
  end

  private

  def handle_channel_error(error)
    Rails.logger.error("ChatChannel Error: #{error.class} - #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))
  end
end

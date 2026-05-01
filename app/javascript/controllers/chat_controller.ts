import BaseChannelController from "./base_channel_controller"

/**
 * Chat Controller - Handles WebSocket + UI for AI coding chat
 *
 * Targets:
 * - messagesTarget: Container for chat messages
 * - inputTarget: Message input field
 * - formTarget: Message form
 *
 * Server sends JSON with 'type' field, automatically routes to handleXxx() methods
 */
export default class extends BaseChannelController {
  static targets = [
    "messages",
    "input",
    "form"
  ]

  static values = {
    streamName: String,
    conversationId: Number
  }

  declare readonly messagesTarget: HTMLElement
  declare readonly inputTarget: HTMLInputElement
  declare readonly formTarget: HTMLFormElement
  declare readonly streamNameValue: string
  declare readonly conversationIdValue: number

  private currentAssistantMessage: HTMLElement | null = null
  private currentContent = ""

  connect(): void {
    console.log("Chat controller connected")

    this.createSubscription("ChatChannel", {
      stream_name: this.streamNameValue
    })
  }

  disconnect(): void {
    this.destroySubscription()
  }

  protected channelConnected(): void {
    console.log("WebSocket connected")
  }

  protected channelDisconnected(): void {
    console.log("WebSocket disconnected")
  }

  // Handle form submission
  submitMessage(event: Event): void {
    event.preventDefault()

    const content = this.inputTarget.value.trim()
    if (!content) return

    // Send message via WebSocket
    this.perform('send_message', {
      conversation_id: this.conversationIdValue,
      content: content
    })

    // Clear input
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }

  // Handle user message broadcast
  protected handleUserMessage(data: any): void {
    this.appendMessage('user', data.content, data.timestamp)
    this.scrollToBottom()
  }

  // Handle AI streaming chunk
  protected handleChunk(data: any): void {
    if (!this.currentAssistantMessage) {
      this.currentAssistantMessage = this.createMessage('assistant')
      this.currentContent = ""
    }

    this.currentContent += data.chunk
    const contentEl = this.currentAssistantMessage.querySelector('.message-content')
    if (contentEl) {
      contentEl.textContent = this.currentContent
    }

    this.scrollToBottom()
  }

  // Handle AI streaming complete
  protected handleComplete(data: any): void {
    if (this.currentAssistantMessage) {
      const contentEl = this.currentAssistantMessage.querySelector('.message-content')
      if (contentEl) {
        contentEl.textContent = data.content
      }
    }
    
    this.currentAssistantMessage = null
    this.currentContent = ""
    this.scrollToBottom()
  }

  // Handle errors
  protected handleError(data: any): void {
    console.error('Chat error:', data.message)
    this.appendMessage('error', `Error: ${data.message}`, new Date().toISOString())
    this.scrollToBottom()
  }

  // Handle tool call (AI is executing a tool)
  protected handleToolCall(data: any): void {
    const toolMessage = this.createToolMessage('call', data.tool_name, data.arguments)
    this.scrollToBottom()
  }

  // Handle tool result (Tool execution completed)
  protected handleToolResult(data: any): void {
    const toolMessage = this.createToolMessage('result', data.tool_name, data.result)
    this.scrollToBottom()
  }

  // Helper: Append complete message
  private appendMessage(role: string, content: string, timestamp: string): void {
    const messageEl = this.createMessage(role)
    const contentEl = messageEl.querySelector('.message-content')
    if (contentEl) {
      contentEl.textContent = content
    }
  }

  // Helper: Create message element
  private createMessage(role: string): HTMLElement {
    const messageEl = document.createElement('div')
    messageEl.className = `message message-${role} mb-4 flex gap-3`

    const avatar = document.createElement('div')
    avatar.className = `w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${role === 'user' ? 'bg-primary/20 text-primary' : 'bg-secondary/20 text-secondary'}`
    avatar.textContent = role === 'user' ? 'U' : 'AI'

    const contentWrapper = document.createElement('div')
    contentWrapper.className = 'flex-1'

    const contentEl = document.createElement('div')
    contentEl.className = 'message-content text-secondary whitespace-pre-wrap'
    contentEl.textContent = ''

    contentWrapper.appendChild(contentEl)
    messageEl.appendChild(avatar)
    messageEl.appendChild(contentWrapper)

    this.messagesTarget.appendChild(messageEl)
    return messageEl
  }

  // Helper: Scroll to bottom
  private scrollToBottom(): void {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  // Helper: Create tool message element
  private createToolMessage(type: 'call' | 'result', toolName: string, data: any): HTMLElement {
    const messageEl = document.createElement('div')
    messageEl.className = 'message message-tool mb-4 flex gap-3'

    const icon = document.createElement('div')
    icon.className = 'w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 bg-accent/20 text-accent'
    icon.innerHTML = type === 'call' ? '🔧' : '✓'

    const contentWrapper = document.createElement('div')
    contentWrapper.className = 'flex-1'

    const toolLabel = document.createElement('div')
    toolLabel.className = 'text-xs font-mono text-tertiary mb-1'
    toolLabel.textContent = type === 'call' ? `Calling ${toolName}...` : `${toolName} completed`

    const contentEl = document.createElement('div')
    contentEl.className = 'text-xs font-mono text-secondary bg-surface/50 p-2 rounded border border-border overflow-x-auto'
    contentEl.textContent = JSON.stringify(data, null, 2)

    contentWrapper.appendChild(toolLabel)
    contentWrapper.appendChild(contentEl)
    messageEl.appendChild(icon)
    messageEl.appendChild(contentWrapper)

    this.messagesTarget.appendChild(messageEl)
    return messageEl
  }
}

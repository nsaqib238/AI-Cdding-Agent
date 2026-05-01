class AiAgentService < ApplicationService
  attr_reader :conversation, :prompt, :stream_name

  def initialize(conversation:, prompt:, stream_name:)
    @conversation = conversation
    @prompt = prompt
    @stream_name = stream_name
  end

  def call
    system_prompt = build_system_prompt

    # Stream LLM response without tool calling for now
    # TODO: Implement tool calling via separate mechanism
    LlmStreamJob.perform_later(
      stream_name: stream_name,
      prompt: prompt,
      system: system_prompt
    )
  end

  private

  def build_system_prompt
    <<~PROMPT
      You are an AI coding assistant. Help users write, understand, and debug code.
      
      You have access to the following tools:
      - read_file: Read the contents of a file
      - write_file: Write or update a file with new content
      - run_command: Execute a shell command safely
      - list_files: List files in a directory
      
      When using tools:
      1. Always verify file paths before reading/writing
      2. Explain what you're doing before executing commands
      3. Show command outputs to the user
      4. Be cautious with destructive operations
      
      Current project: #{conversation.project&.name || 'None'}
      Project path: #{conversation.project&.absolute_path || 'None'}
    PROMPT
  end

  def handle_tool_call(tool_name, arguments)
    case tool_name
    when 'read_file'
      read_file_tool(arguments)
    when 'write_file'
      write_file_tool(arguments)
    when 'run_command'
      run_command_tool(arguments)
    when 'list_files'
      list_files_tool(arguments)
    else
      { error: "Unknown tool: #{tool_name}" }
    end
  rescue StandardError => e
    { error: e.message }
  end

  def read_file_tool(arguments)
    file_path = arguments['path']
    project = conversation.project
    return { error: 'No project associated' } unless project

    # Read directly from filesystem
    content = project.read_file(file_path)
    if content.nil?
      return { error: "File not found: #{file_path}" }
    end

    # Track in database (optional)
    coding_file = project.coding_files.find_or_initialize_by(relative_path: file_path)
    if coding_file.exists?
      coding_file.update(last_modified_at: File.mtime(coding_file.absolute_path))
    end

    {
      path: file_path,
      content: content,
      size: content.bytesize
    }
  end

  def write_file_tool(arguments)
    file_path = arguments['path']
    content = arguments['content']
    project = conversation.project
    return { error: 'No project associated' } unless project

    # Write directly to filesystem
    begin
      coding_file = project.write_file(file_path, content)
      
      {
        path: file_path,
        size: coding_file.size,
        version: coding_file.version,
        success: true
      }
    rescue => e
      { error: "Failed to write file: #{e.message}" }
    end
  end

  def run_command_tool(arguments)
    command = arguments['command']
    project = conversation.project
    return { error: 'No project associated' } unless project

    # Create command execution record
    execution = conversation.command_executions.create!(
      command: command,
      status: 'running'
    )

    begin
      # Execute command in project directory
      output = `cd #{project.absolute_path} && #{command} 2>&1`
      exit_code = $?.exitstatus

      execution.update(
        output: output,
        exit_code: exit_code,
        status: exit_code.zero? ? 'completed' : 'failed'
      )

      {
        success: exit_code.zero?,
        output: output,
        exit_code: exit_code,
        command: command
      }
    rescue StandardError => e
      execution.update(
        output: e.message,
        status: 'failed'
      )

      { error: e.message }
    end
  end

  def list_files_tool(arguments)
    project = conversation.project
    return { error: 'No project associated' } unless project

    pattern = arguments['pattern'] || '**/*'
    include_hidden = arguments['include_hidden'] || false

    # List files directly from filesystem
    files = project.list_files(pattern: pattern, include_hidden: include_hidden)
    
    {
      files: files,
      count: files.length
    }
  end
end

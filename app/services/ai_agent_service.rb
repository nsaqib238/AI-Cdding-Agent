class AiAgentService < ApplicationService
  include AiAgentServiceTools
  
  attr_reader :conversation, :prompt, :stream_name

  def initialize(conversation:, prompt:, stream_name:)
    @conversation = conversation
    @prompt = prompt
    @stream_name = stream_name
  end

  def call
    system_prompt = build_system_prompt

    # Stream LLM response with tool calling enabled
    LlmStreamJob.perform_later(
      stream_name: stream_name,
      prompt: prompt,
      system: system_prompt,
      conversation_id: conversation.id,
      tools: build_tool_definitions
    )
  end

  private

  def build_tool_definitions
    [
      {
        type: "function",
        function: {
          name: "read_file",
          description: "Read the contents of a file from the project directory",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Relative path to the file (e.g., 'app/models/user.rb')"
              }
            },
            required: ["path"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "write_file",
          description: "Write or update a file with new content. Creates the file and parent directories if they don't exist.",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Relative path to the file (e.g., 'app/services/new_service.rb')"
              },
              content: {
                type: "string",
                description: "The complete file content to write"
              }
            },
            required: ["path", "content"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "run_command",
          description: "Execute a shell command in the project directory. Use for running tests, builds, git commands, etc.",
          parameters: {
            type: "object",
            properties: {
              command: {
                type: "string",
                description: "The shell command to execute (e.g., 'rails test', 'npm install')"
              }
            },
            required: ["command"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "list_files",
          description: "List files in the project directory matching a pattern",
          parameters: {
            type: "object",
            properties: {
              pattern: {
                type: "string",
                description: "Glob pattern to match files (e.g., '**/*.rb' for all Ruby files, '**/*' for all files)",
                default: "**/*"
              },
              include_hidden: {
                type: "boolean",
                description: "Whether to include hidden files (starting with .)",
                default: false
              }
            },
            required: []
          }
        }
      },
      # Level 6-7: Project Context Awareness
      {
        type: "function",
        function: {
          name: "search_files",
          description: "Search for text patterns across all project files (grep-like). Returns matching lines with context.",
          parameters: {
            type: "object",
            properties: {
              query: {
                type: "string",
                description: "Text or regex pattern to search for"
              },
              file_pattern: {
                type: "string",
                description: "Limit search to files matching this glob pattern (e.g., '**/*.rb')",
                default: "**/*"
              },
              case_sensitive: {
                type: "boolean",
                default: false
              },
              context_lines: {
                type: "integer",
                description: "Number of lines before/after match to include",
                default: 2
              }
            },
            required: ["query"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "analyze_project",
          description: "Analyze project structure and provide comprehensive stats (file types, dependencies, test coverage, etc.)",
          parameters: {
            type: "object",
            properties: {
              include_dependencies: {
                type: "boolean",
                description: "Include dependency analysis from Gemfile/package.json",
                default: true
              }
            },
            required: []
          }
        }
      },
      {
        type: "function",
        function: {
          name: "find_references",
          description: "Find all references to a symbol (class, method, variable) across the codebase",
          parameters: {
            type: "object",
            properties: {
              symbol: {
                type: "string",
                description: "The symbol name to find (e.g., 'User', 'process_payment', 'DATABASE_URL')"
              },
              file_pattern: {
                type: "string",
                description: "Limit search to specific file types",
                default: "**/*.{rb,js,ts,erb,yml}"
              }
            },
            required: ["symbol"]
          }
        }
      },
      # Level 8: Code Analysis
      {
        type: "function",
        function: {
          name: "parse_ruby_ast",
          description: "Parse Ruby file into AST and extract structure (classes, methods, constants, dependencies)",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Path to Ruby file to analyze"
              }
            },
            required: ["path"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "get_file_dependencies",
          description: "Analyze file dependencies (requires, imports, includes) and their resolution",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Path to file to analyze"
              }
            },
            required: ["path"]
          }
        }
      },
      # Level 9: Git Integration & Testing
      {
        type: "function",
        function: {
          name: "git_status",
          description: "Get current git status (modified files, staged changes, branch info)",
          parameters: {
            type: "object",
            properties: {},
            required: []
          }
        }
      },
      {
        type: "function",
        function: {
          name: "git_diff",
          description: "Show git diff for specific file or all changes",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Specific file to diff (omit for all changes)"
              },
              staged: {
                type: "boolean",
                description: "Show staged changes only",
                default: false
              }
            },
            required: []
          }
        }
      },
      {
        type: "function",
        function: {
          name: "git_commit",
          description: "Create a git commit with staged changes",
          parameters: {
            type: "object",
            properties: {
              message: {
                type: "string",
                description: "Commit message"
              },
              files: {
                type: "array",
                description: "Specific files to stage and commit (omit to commit all staged)",
                items: { type: "string" }
              }
            },
            required: ["message"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "run_tests",
          description: "Run project tests with intelligent output parsing and failure analysis",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Specific test file or directory to run (omit for all tests)"
              },
              pattern: {
                type: "string",
                description: "Run tests matching this pattern/description"
              }
            },
            required: []
          }
        }
      },
      # Level 10: Advanced Refactoring & Debugging
      {
        type: "function",
        function: {
          name: "refactor_code",
          description: "Intelligently refactor code (extract method, rename symbol, move class, etc.)",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "File to refactor"
              },
              refactoring_type: {
                type: "string",
                description: "Type of refactoring",
                enum: ["extract_method", "rename_symbol", "inline_variable", "extract_class"]
              },
              options: {
                type: "object",
                description: "Refactoring-specific options (e.g., new_name, line_range, target_class)"
              }
            },
            required: ["path", "refactoring_type"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "analyze_performance",
          description: "Analyze code performance and suggest optimizations (N+1 queries, inefficient loops, etc.)",
          parameters: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "File to analyze"
              },
              check_types: {
                type: "array",
                description: "Specific checks to run",
                items: {
                  type: "string",
                  enum: ["n_plus_one", "memory_leaks", "slow_queries", "inefficient_loops", "all"]
                },
                default: ["all"]
              }
            },
            required: ["path"]
          }
        }
      }
    ]
  end

  def build_system_prompt
    <<~PROMPT
      You are an AI coding assistant. Help users write, understand, and debug code.
      
      You have access to powerful tools:
      
      Basic Operations:
      - read_file, write_file, run_command, list_files
      
      Code Intelligence (Level 6-8):
      - search_files: Grep-like search across codebase
      - analyze_project: Full project analysis and stats
      - find_references: Find all uses of a symbol
      - parse_ruby_ast: Analyze Ruby code structure
      - get_file_dependencies: Trace imports and requires
      
      Git & Testing (Level 9):
      - git_status, git_diff, git_commit: Git operations
      - run_tests: Run and analyze test results
      
      Advanced (Level 10):
      - refactor_code: Intelligent code refactoring
      - analyze_performance: Find performance issues
      
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
    # Basic tools
    when 'read_file'
      read_file_tool(arguments)
    when 'write_file'
      write_file_tool(arguments)
    when 'run_command'
      run_command_tool(arguments)
    when 'list_files'
      list_files_tool(arguments)
    # Level 6-7: Context awareness
    when 'search_files'
      search_files_tool(arguments)
    when 'analyze_project'
      analyze_project_tool(arguments)
    when 'find_references'
      find_references_tool(arguments)
    # Level 8: Code analysis
    when 'parse_ruby_ast'
      parse_ruby_ast_tool(arguments)
    when 'get_file_dependencies'
      get_file_dependencies_tool(arguments)
    # Level 9: Git & testing
    when 'git_status'
      git_status_tool(arguments)
    when 'git_diff'
      git_diff_tool(arguments)
    when 'git_commit'
      git_commit_tool(arguments)
    when 'run_tests'
      run_tests_tool(arguments)
    # Level 10: Advanced
    when 'refactor_code'
      refactor_code_tool(arguments)
    when 'analyze_performance'
      analyze_performance_tool(arguments)
    else
      { error: "Unknown tool: #{tool_name}" }
    end
  rescue StandardError => e
    { error: e.message, backtrace: e.backtrace.first(5) }
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

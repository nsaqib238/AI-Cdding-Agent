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
    clackyrules_content = load_clackyrules
    
    <<~PROMPT
      You are an expert Rails 7.2 full-stack developer with deep knowledge of modern web architecture, security, testing, and best practices.
      
      ═══════════════════════════════════════════════════════════════════════════════
      ⚠️  MANDATORY PROJECT CONVENTIONS (ABSOLUTE PRIORITY)
      ═══════════════════════════════════════════════════════════════════════════════
      
      #{clackyrules_content}
      
      ═══════════════════════════════════════════════════════════════════════════════
      📚 RAILS ARCHITECTURE & BEST PRACTICES
      ═══════════════════════════════════════════════════════════════════════════════
      
      ## MVC Architecture Patterns:
      
      **Models:**
      - Keep models thin - use concerns for shared behavior
      - Business logic belongs in service objects (app/services/)
      - Use scopes for common queries: scope :active, -> { where(status: 'active') }
      - Validate all user inputs: validates :email, presence: true, uniqueness: true
      - Use database constraints for data integrity (NOT NULL, UNIQUE, FOREIGN KEY)
      
      **Controllers:**
      - Keep controllers thin - delegate to services for complex logic
      - Use strong_parameters for mass assignment protection (ALWAYS)
      - Follow RESTful conventions: index, show, new, create, edit, update, destroy
      - Use before_action for authentication/authorization checks
      - Prefer rendering HTML views; use Turbo Stream for partial updates
      
      **Views:**
      - Use partials for reusable components: render 'shared/card', item: @item
      - Use helpers for view-specific logic (NOT business logic)
      - Always use semantic HTML5 tags
      - Follow the project's design system (Tailwind semantic tokens)
      
      **Services:**
      - One service per complex operation (e.g., ProcessPaymentService)
      - Return Result objects or raise specific errors
      - Keep services focused on single responsibility
      - Example: class ProcessOrderService < ApplicationService
      
      ═══════════════════════════════════════════════════════════════════════════════
      🔒 SECURITY BEST PRACTICES (MANDATORY)
      ═══════════════════════════════════════════════════════════════════════════════
      
      **Input Validation & Sanitization:**
      - ALWAYS use strong_parameters in controllers
      - Validate ALL user inputs at model level
      - Never trust user input - sanitize before database/display
      - Use Rails built-in helpers: sanitize, strip_tags
      
      **Authentication & Authorization:**
      - Use before_action :authenticate_user! for protected routes
      - Check authorization before any data access/modification
      - Never expose user passwords or sensitive data in logs/responses
      - Use secure password hashing (bcrypt - already built into Rails)
      
      **SQL Injection Prevention:**
      - ALWAYS use parameterized queries (Rails handles this by default)
      - NEVER interpolate user input into SQL: User.where("email = ?", email) ✅
      - AVOID raw SQL unless absolutely necessary
      
      **XSS Prevention:**
      - Rails auto-escapes HTML in ERB (<%=  %> is safe)
      - Use html_safe ONLY on trusted content
      - Sanitize user-generated HTML content
      
      **CSRF Protection:**
      - Keep protect_from_forgery enabled (Rails default)
      - Include CSRF token in all forms (form_with does this automatically)
      
      **Data Exposure:**
      - Never return full model objects in JSON APIs without serializers
      - Exclude sensitive fields: User.select(:id, :name, :email) - no passwords!
      - Use .gitignore for secrets (already configured)
      
      ═══════════════════════════════════════════════════════════════════════════════
      ✅ TESTING REQUIREMENTS (MANDATORY)
      ═══════════════════════════════════════════════════════════════════════════════
      
      **Test-Driven Development:**
      - Write tests BEFORE implementing features (TDD approach preferred)
      - Run tests after EVERY significant change
      - NEVER deliver code with failing tests
      
      **RSpec Testing Strategy:**
      - Request specs for controller/integration tests: spec/requests/
      - Model specs for business logic: spec/models/
      - System specs for end-to-end flows: spec/system/
      - Service specs for complex operations: spec/services/
      
      **Test Structure:**
      - Use describe for grouping related tests
      - Use context for different scenarios
      - Use it/specify for individual test cases
      - Use let for test data setup
      - Follow "Arrange, Act, Assert" pattern
      
      **Test Coverage:**
      - Aim for 80%+ code coverage
      - Test happy paths AND edge cases
      - Test error handling and validation failures
      - Test authorization checks (can user access this?)
      
      ═══════════════════════════════════════════════════════════════════════════════
      🎨 CODE QUALITY STANDARDS (RUBY STYLE GUIDE)
      ═══════════════════════════════════════════════════════════════════════════════
      
      **Formatting:**
      - 2-space indentation (soft tabs)
      - Max line length: 120 characters
      - Use snake_case for methods, variables: def process_payment
      - Use CamelCase for classes, modules: class PaymentProcessor
      - Use SCREAMING_SNAKE_CASE for constants: MAX_RETRIES = 3
      
      **Method Design:**
      - Keep methods under 10 lines (extract if longer)
      - Methods should do ONE thing well (Single Responsibility)
      - Use descriptive names: calculate_total_with_tax vs calc
      - Return early for error cases (guard clauses)
      - Prefer keyword arguments for methods with 3+ parameters
      
      **Code Organization:**
      - Group related methods together
      - Public methods first, then private methods
      - Use private for internal implementation details
      - Use # frozen_string_literal: true at top of files
      
      **Rails Idioms:**
      - Use Rails helpers: present?, blank?, try(:method)
      - Prefer safe navigation: user&.email instead of user && user.email
      - Use symbols for hash keys: { name: 'John' } not { 'name' => 'John' }
      - Chain query methods: User.active.where(role: 'admin').order(:name)
      
      **Avoid:**
      - Long methods (over 10 lines) → extract to smaller methods
      - Deep nesting (over 3 levels) → extract to methods or use guard clauses
      - Magic numbers → use named constants: DISCOUNT_RATE = 0.15
      - Comments that explain WHAT code does → code should be self-documenting
      - Commented-out code → delete it (Git history preserves it)
      
      **When to Comment:**
      - Complex business logic that isn't obvious
      - WHY decisions were made (not WHAT code does)
      - Security considerations or gotchas
      - Temporary workarounds (with TODO and ticket reference)
      
      ═══════════════════════════════════════════════════════════════════════════════
      🛠️  YOUR POWERFUL TOOL ARSENAL
      ═══════════════════════════════════════════════════════════════════════════════
      
      **File Operations:**
      - read_file: Read file contents from project
      - write_file: Create/update files (auto-creates directories)
      - list_files: List files matching patterns
      
      **Code Intelligence:**
      - search_files: Grep-like regex search across entire codebase with context
      - analyze_project: Comprehensive project stats (LOC, dependencies, file types)
      - find_references: Find all uses of classes/methods/variables
      - parse_ruby_ast: Deep Ruby code structure analysis (classes, methods, constants)
      - get_file_dependencies: Trace requires/imports and resolve paths
      
      **Git Operations:**
      - git_status: Show current branch, staged/unstaged changes
      - git_diff: Show code changes (staged or unstaged)
      - git_commit: Create commits with messages
      
      **Testing & Quality:**
      - run_tests: Execute RSpec/Minitest with intelligent output parsing
      - run_command: Execute ANY shell command in project directory
      - analyze_performance: Find N+1 queries, slow loops, memory leaks
      
      **Advanced Refactoring:**
      - refactor_code: Intelligent code refactoring (rename symbols, extract methods)
      
      ═══════════════════════════════════════════════════════════════════════════════
      💡 DEVELOPMENT WORKFLOW (FOLLOW THIS PROCESS)
      ═══════════════════════════════════════════════════════════════════════════════
      
      **For Every Feature Request:**
      
      1. **Understand Context:**
         - Use search_files to find related code
         - Use analyze_project to understand project structure
         - Use find_references to see how existing features work
      
      2. **Plan Architecture:**
         - Decide: Model? Controller? Service? All three?
         - Follow Rails conventions (RESTful routes, MVC separation)
         - Check if generators can help (rails g authentication, etc.)
      
      3. **Implement Incrementally:**
         - Start with database migrations/models
         - Add controller actions with strong_parameters
         - Create views using project's design system
         - Add routes following RESTful conventions
      
      4. **Write Tests:**
         - Request specs for controller actions
         - Model specs for validations and business logic
         - Use run_tests frequently during development
      
      5. **Verify Quality:**
         - Run rake test (MANDATORY before completion)
         - Use analyze_performance to check for issues
         - Use git_diff to review changes
      
      6. **Commit Changes:**
         - Use git_status to see what changed
         - Use git_commit with descriptive messages
      
      **For Debugging:**
      
      1. Read error messages carefully
      2. Use search_files to find related code
      3. Check logs: run_command 'tail -n 100 log/development.log'
      4. Run specific tests: run_tests path: 'spec/requests/users_spec.rb'
      5. Fix and verify with run_tests
      
      ═══════════════════════════════════════════════════════════════════════════════
      🎯 CRITICAL REMINDERS
      ═══════════════════════════════════════════════════════════════════════════════
      
      1. **ALWAYS follow the MANDATORY PROJECT WORKFLOW from .clackyrules**
      2. **NEVER skip rake test before completing features**
      3. **ALWAYS use strong_parameters in controllers**
      4. **ALWAYS validate user inputs in models**
      5. **ALWAYS follow Turbo Stream architecture (no fetch, no respond_to)**
      6. **ALWAYS use project generators instead of manual creation**
      7. **ALWAYS run tests after making changes**
      8. **ALWAYS use semantic design tokens (no text-white, bg-black)**
      9. **ALWAYS use Stimulus for frontend (no inline JS, no jQuery)**
      10. **NEVER expose passwords or sensitive data**
      
      ═══════════════════════════════════════════════════════════════════════════════
      
      Current project: #{conversation.project&.name || 'None'}
      Project path: #{conversation.project&.absolute_path || 'None'}
      
      You are now equipped to build robust, secure, well-tested Rails applications.
      When in doubt, use your tools to explore the codebase and follow Rails conventions.
    PROMPT
  end
  
  def load_clackyrules
    clackyrules_path = Rails.root.join('.clackyrules')
    if File.exist?(clackyrules_path)
      File.read(clackyrules_path)
    else
      "# .clackyrules file not found - using default conventions"
    end
  rescue StandardError => e
    "# Error loading .clackyrules: #{e.message}"
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

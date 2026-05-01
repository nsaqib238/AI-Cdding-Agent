# Advanced tool implementations for AI agent (Level 6-10)
# These methods are included in AiAgentService
module AiAgentServiceTools
  # ========== Level 6-7: Context Awareness ==========
  
  def search_files_tool(arguments)
    query = arguments['query']
    file_pattern = arguments['file_pattern'] || '**/*'
    case_sensitive = arguments['case_sensitive'] || false
    context_lines = arguments['context_lines'] || 2
    project = conversation.project
    return { error: 'No project associated' } unless project

    matches = []
    files = Dir.glob(File.join(project.absolute_path, file_pattern)).select { |f| File.file?(f) }
    
    regex = Regexp.new(query, case_sensitive ? nil : Regexp::IGNORECASE)
    
    files.each do |file_path|
      next unless File.readable?(file_path)
      relative_path = file_path.sub("#{project.absolute_path}/", '')
      
      begin
        lines = File.readlines(file_path)
        lines.each_with_index do |line, index|
          if line.match?(regex)
            # Get context lines
            start_line = [0, index - context_lines].max
            end_line = [lines.length - 1, index + context_lines].min
            context = lines[start_line..end_line].map.with_index do |l, i|
              line_num = start_line + i + 1
              marker = (start_line + i == index) ? '>' : ' '
              "#{marker} #{line_num}: #{l.chomp}"
            end.join("\n")
            
            matches << {
              file: relative_path,
              line_number: index + 1,
              match: line.chomp,
              context: context
            }
          end
        end
      rescue StandardError => e
        # Skip binary or unreadable files
        next
      end
    end

    {
      query: query,
      matches: matches.first(100), # Limit to 100 matches
      total_matches: matches.length,
      files_searched: files.length
    }
  end

  def analyze_project_tool(arguments)
    include_dependencies = arguments.fetch('include_dependencies', true)
    project = conversation.project
    return { error: 'No project associated' } unless project

    all_files = Dir.glob(File.join(project.absolute_path, '**/*')).select { |f| File.file?(f) }
    
    # File type breakdown
    file_types = all_files.group_by { |f| File.extname(f) }.transform_values(&:count)
    
    # Directory structure (top-level only)
    top_dirs = Dir.glob(File.join(project.absolute_path, '*')).select { |d| File.directory?(d) }
      .map { |d| File.basename(d) }
    
    # LOC analysis
    code_files = all_files.select { |f| ['.rb', '.js', '.ts', '.erb', '.jsx', '.tsx'].include?(File.extname(f)) }
    total_loc = code_files.sum do |file|
      File.readlines(file).reject { |line| line.strip.empty? || line.strip.start_with?('#', '//') }.count
    rescue
      0
    end

    # Test files
    test_files = all_files.select { |f| f.include?('/spec/') || f.include?('/test/') }
    
    analysis = {
      project_name: project.name,
      total_files: all_files.length,
      total_loc: total_loc,
      file_types: file_types.sort_by { |_, count| -count }.first(10).to_h,
      top_directories: top_dirs,
      test_files_count: test_files.length,
      test_coverage_estimate: test_files.length > 0 ? "#{(test_files.length.to_f / code_files.length * 100).round}%" : '0%'
    }

    if include_dependencies
      # Parse Gemfile
      gemfile_path = File.join(project.absolute_path, 'Gemfile')
      if File.exist?(gemfile_path)
        begin
          gemfile_content = File.read(gemfile_path)
          gems = gemfile_content.lines
            .select { |line| line.strip.start_with?('gem ') }
            .map { |line| line.match(/gem\s+['"]([^'"]+)['"]/)[1] rescue nil }
            .compact
          analysis[:ruby_gems] = gems.first(20) if gems.any?
        rescue StandardError
          # Skip if Gemfile parsing fails
        end
      end

      # Parse package.json
      package_json_path = File.join(project.absolute_path, 'package.json')
      if File.exist?(package_json_path)
        begin
          require 'json'
          package_data = JSON.parse(File.read(package_json_path))
          analysis[:npm_dependencies] = package_data.dig('dependencies')&.keys&.first(20) || []
        rescue StandardError
          # Skip if package.json parsing fails
        end
      end
    end

    analysis
  end

  def find_references_tool(arguments)
    symbol = arguments['symbol']
    file_pattern = arguments['file_pattern'] || '**/*.{rb,js,ts,erb,yml}'
    project = conversation.project
    return { error: 'No project associated' } unless project

    references = []
    files = Dir.glob(File.join(project.absolute_path, file_pattern)).select { |f| File.file?(f) }
    
    # Use word boundary for more accurate matching
    regex = /\b#{Regexp.escape(symbol)}\b/
    
    files.each do |file_path|
      next unless File.readable?(file_path)
      relative_path = file_path.sub("#{project.absolute_path}/", '')
      
      begin
        File.readlines(file_path).each_with_index do |line, index|
          if line.match?(regex)
            references << {
              file: relative_path,
              line_number: index + 1,
              line_content: line.chomp,
              context_type: detect_context_type(line, symbol)
            }
          end
        end
      rescue StandardError
        next
      end
    end

    {
      symbol: symbol,
      references: references.first(100),
      total_references: references.length,
      files_with_references: references.map { |r| r[:file] }.uniq.length
    }
  end

  # ========== Level 8: Code Analysis ==========
  
  def parse_ruby_ast_tool(arguments)
    file_path = arguments['path']
    project = conversation.project
    return { error: 'No project associated' } unless project

    return { error: "Not a Ruby file" } unless file_path.end_with?('.rb')
    
    full_path = File.join(project.absolute_path, file_path)
    return { error: "File not found: #{file_path}" } unless File.exist?(full_path)

    require 'parser/current'
    
    begin
      source_code = File.read(full_path)
      ast = Parser::CurrentRuby.parse(source_code)
      
      structure = {
        file: file_path,
        classes: extract_classes(ast),
        modules: extract_modules(ast),
        methods: extract_methods(ast),
        constants: extract_constants(ast),
        dependencies: extract_requires(ast)
      }
      
      structure
    rescue Parser::SyntaxError => e
      { error: "Syntax error: #{e.message}", line: e.diagnostic.location.line }
    end
  end

  def get_file_dependencies_tool(arguments)
    file_path = arguments['path']
    project = conversation.project
    return { error: 'No project associated' } unless project

    full_path = File.join(project.absolute_path, file_path)
    return { error: "File not found: #{file_path}" } unless File.exist?(full_path)

    content = File.read(full_path)
    dependencies = []

    # Ruby requires
    content.scan(/require\s+['"]([^'"]+)['"]/).flatten.each do |dep|
      dependencies << { type: 'require', name: dep, resolved: resolve_ruby_path(project, dep) }
    end
    
    content.scan(/require_relative\s+['"]([^'"]+)['"]/).flatten.each do |dep|
      dependencies << { type: 'require_relative', name: dep, resolved: resolve_relative_path(full_path, dep) }
    end

    # JavaScript/TypeScript imports
    content.scan(/import\s+.*?from\s+['"]([^'"]+)['"]/).flatten.each do |dep|
      dependencies << { type: 'import', name: dep, resolved: resolve_js_path(project, dep) }
    end

    {
      file: file_path,
      dependencies: dependencies,
      total_dependencies: dependencies.length
    }
  end

  # ========== Level 9: Git Integration ==========
  
  def git_status_tool(_arguments)
    project = conversation.project
    return { error: 'No project associated' } unless project

    begin
      Dir.chdir(project.absolute_path) do
        return { error: 'Not a git repository' } unless Dir.exist?('.git')

        branch = `git branch --show-current`.strip
        modified = `git status --porcelain`.split("\n").map { |line| { status: line[0..1].strip, file: line[3..-1] } }
        staged = modified.select { |f| f[:status].match?(/^[MADRC]/) }
        unstaged = modified.select { |f| f[:status].match?(/^.[MD]/) }
        untracked = modified.select { |f| f[:status] == '??' }

        {
          branch: branch,
          staged_files: staged,
          unstaged_files: unstaged,
          untracked_files: untracked,
          is_clean: modified.empty?
        }
      end
    rescue StandardError => e
      { error: e.message }
    end
  end

  def git_diff_tool(arguments)
    file_path = arguments['path']
    staged = arguments.fetch('staged', false)
    project = conversation.project
    return { error: 'No project associated' } unless project

    begin
      Dir.chdir(project.absolute_path) do
        return { error: 'Not a git repository' } unless Dir.exist?('.git')

        cmd = staged ? 'git diff --staged' : 'git diff'
        cmd += " #{file_path}" if file_path
        diff = `#{cmd}`

        {
          diff: diff,
          file: file_path,
          staged: staged,
          has_changes: !diff.empty?
        }
      end
    rescue StandardError => e
      { error: e.message }
    end
  end

  def git_commit_tool(arguments)
    message = arguments['message']
    files = arguments['files']
    project = conversation.project
    return { error: 'No project associated' } unless project
    return { error: 'Commit message required' } if message.blank?

    begin
      Dir.chdir(project.absolute_path) do
        return { error: 'Not a git repository' } unless Dir.exist?('.git')

        # Stage files if specified
        if files.present?
          files.each { |file| system("git add #{file}") }
        end

        # Commit
        result = `git commit -m "#{message}" 2>&1`
        success = $?.success?

        if success
          commit_hash = `git rev-parse HEAD`.strip[0..7]
          {
            success: true,
            message: message,
            commit_hash: commit_hash,
            output: result
          }
        else
          { error: result }
        end
      end
    rescue StandardError => e
      { error: e.message }
    end
  end

  def run_tests_tool(arguments)
    test_path = arguments['path']
    pattern = arguments['pattern']
    project = conversation.project
    return { error: 'No project associated' } unless project

    begin
      Dir.chdir(project.absolute_path) do
        # Detect test framework
        if File.exist?('spec')
          cmd = 'bundle exec rspec'
          cmd += " #{test_path}" if test_path
          cmd += " -e '#{pattern}'" if pattern
        elsif File.exist?('test')
          cmd = 'rails test'
          cmd += " #{test_path}" if test_path
        else
          return { error: 'No test framework detected (spec/ or test/ directory)' }
        end

        output = `#{cmd} 2>&1`
        exit_code = $?.exitstatus

        # Parse results
        parsed = parse_test_output(output)
        
        {
          success: exit_code.zero?,
          exit_code: exit_code,
          output: output,
          summary: parsed[:summary],
          failures: parsed[:failures],
          test_path: test_path
        }
      end
    rescue StandardError => e
      { error: e.message }
    end
  end

  # ========== Level 10: Advanced Features ==========
  
  def refactor_code_tool(arguments)
    file_path = arguments['path']
    refactoring_type = arguments['refactoring_type']
    options = arguments['options'] || {}
    project = conversation.project
    return { error: 'No project associated' } unless project

    full_path = File.join(project.absolute_path, file_path)
    return { error: "File not found: #{file_path}" } unless File.exist?(full_path)

    begin
      content = File.read(full_path)
      
      case refactoring_type
      when 'rename_symbol'
        old_name = options['old_name']
        new_name = options['new_name']
        return { error: 'old_name and new_name required' } unless old_name && new_name
        
        new_content = content.gsub(/\b#{Regexp.escape(old_name)}\b/, new_name)
        occurrences = content.scan(/\b#{Regexp.escape(old_name)}\b/).length
        
        {
          refactoring: 'rename_symbol',
          old_name: old_name,
          new_name: new_name,
          occurrences_replaced: occurrences,
          preview: new_content.lines.first(10).join,
          full_content: new_content
        }
        
      when 'extract_method'
        # Basic extract method simulation
        start_line = options['start_line']
        end_line = options['end_line']
        method_name = options['method_name']
        
        return { error: 'start_line, end_line, method_name required' } unless start_line && end_line && method_name
        
        lines = content.lines
        extracted_code = lines[(start_line-1)..(end_line-1)].join
        
        {
          refactoring: 'extract_method',
          method_name: method_name,
          extracted_code: extracted_code,
          suggestion: "def #{method_name}\n  #{extracted_code}\nend"
        }
        
      else
        { error: "Refactoring type '#{refactoring_type}' not yet implemented" }
      end
    rescue StandardError => e
      { error: e.message }
    end
  end

  def analyze_performance_tool(arguments)
    file_path = arguments['path']
    check_types = arguments['check_types'] || ['all']
    project = conversation.project
    return { error: 'No project associated' } unless project

    full_path = File.join(project.absolute_path, file_path)
    return { error: "File not found: #{file_path}" } unless File.exist?(full_path)

    begin
      content = File.read(full_path)
      issues = []

      # N+1 Query Detection (Rails specific)
      if check_types.include?('n_plus_one') || check_types.include?('all')
        content.lines.each_with_index do |line, index|
          if line.match?(/\.each.*\.(find|where|first|last)/)
            issues << {
              type: 'n_plus_one',
              line: index + 1,
              code: line.strip,
              severity: 'high',
              suggestion: 'Use eager loading with includes() or joins() to avoid N+1 queries'
            }
          end
        end
      end

      # Inefficient loops
      if check_types.include?('inefficient_loops') || check_types.include?('all')
        content.lines.each_with_index do |line, index|
          if line.match?(/\.each.*<</) && !line.match?(/\.map|\.select|\.reject/)
            issues << {
              type: 'inefficient_loop',
              line: index + 1,
              code: line.strip,
              severity: 'medium',
              suggestion: 'Consider using map, select, or other enumerable methods instead of each with <<'
            }
          end
        end
      end

      # Slow query patterns
      if check_types.include?('slow_queries') || check_types.include?('all')
        content.lines.each_with_index do |line, index|
          if line.match?(/\.all/) && line.match?(/\.(select|map|each)/)
            issues << {
              type: 'slow_query',
              line: index + 1,
              code: line.strip,
              severity: 'high',
              suggestion: 'Loading all records into memory can be slow. Use find_each, pluck, or limit the query'
            }
          end
        end
      end

      {
        file: file_path,
        checks_performed: check_types,
        issues: issues,
        total_issues: issues.length,
        severity_breakdown: issues.group_by { |i| i[:severity] }.transform_values(&:count)
      }
    rescue StandardError => e
      { error: e.message }
    end
  end

  private

  # ========== Helper Methods ==========
  
  def detect_context_type(line, symbol)
    case line
    when /class\s+#{symbol}/
      'class_definition'
    when /def\s+#{symbol}/
      'method_definition'
    when /module\s+#{symbol}/
      'module_definition'
    when /#{symbol}\s*=/
      'assignment'
    when /#{symbol}\(/
      'method_call'
    else
      'reference'
    end
  end

  def extract_classes(ast)
    return [] unless ast
    classes = []
    ast.each_node(:class) do |node|
      classes << {
        name: node.children[0].children.last.to_s,
        superclass: node.children[1]&.children&.last&.to_s,
        line: node.location.line
      }
    end
    classes
  end

  def extract_modules(ast)
    return [] unless ast
    modules = []
    ast.each_node(:module) do |node|
      modules << {
        name: node.children[0].children.last.to_s,
        line: node.location.line
      }
    end
    modules
  end

  def extract_methods(ast)
    return [] unless ast
    methods = []
    ast.each_node(:def) do |node|
      methods << {
        name: node.children[0].to_s,
        arity: node.children[1].children.length,
        line: node.location.line
      }
    end
    methods
  end

  def extract_constants(ast)
    return [] unless ast
    constants = []
    ast.each_node(:casgn) do |node|
      constants << {
        name: node.children[1].to_s,
        line: node.location.line
      }
    end
    constants
  end

  def extract_requires(ast)
    return [] unless ast
    requires = []
    ast.each_node(:send) do |node|
      if [:require, :require_relative].include?(node.children[1])
        requires << node.children[2].children[0]
      end
    end
    requires
  end

  def resolve_ruby_path(project, dep)
    # Check in project lib/
    lib_path = File.join(project.absolute_path, 'lib', "#{dep}.rb")
    return lib_path if File.exist?(lib_path)
    
    # Gem or stdlib
    'gem_or_stdlib'
  end

  def resolve_relative_path(current_file, relative_path)
    dir = File.dirname(current_file)
    resolved = File.expand_path("#{relative_path}.rb", dir)
    File.exist?(resolved) ? resolved : 'unresolved'
  end

  def resolve_js_path(project, dep)
    # Check node_modules
    node_modules = File.join(project.absolute_path, 'node_modules', dep)
    return 'node_modules' if Dir.exist?(node_modules)
    
    # Check project files
    ['app/javascript', 'app/assets/javascripts'].each do |base|
      full_path = File.join(project.absolute_path, base, "#{dep}.js")
      return full_path if File.exist?(full_path)
      
      full_path_ts = File.join(project.absolute_path, base, "#{dep}.ts")
      return full_path_ts if File.exist?(full_path_ts)
    end
    
    'unresolved'
  end

  def parse_test_output(output)
    summary = {}
    failures = []

    # RSpec format
    if output.match?(/(\d+) examples?, (\d+) failures?/)
      summary[:framework] = 'rspec'
      summary[:total] = output.match(/(\d+) examples?/)[1].to_i
      summary[:failures] = output.match(/(\d+) failures?/)[1].to_i
      summary[:passed] = summary[:total] - summary[:failures]
      
      # Extract failure details
      output.scan(/rspec (.*):(\d+).*# (.*)/).each do |file, line, description|
        failures << { file: file, line: line.to_i, description: description }
      end
    # Minitest format
    elsif output.match?(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/)
      summary[:framework] = 'minitest'
      matches = output.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors/)
      summary[:total] = matches[1].to_i
      summary[:failures] = matches[3].to_i + matches[4].to_i
      summary[:passed] = summary[:total] - summary[:failures]
    end

    { summary: summary, failures: failures }
  end
end

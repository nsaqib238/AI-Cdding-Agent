# Example: Adding a "Find TODOs" Tool

This is a complete, real-world example of adding a new tool to your AI coding assistant. Follow along to see the exact process.

---

## What We're Building

A tool that searches for TODO/FIXME/HACK/NOTE comments in your codebase and returns them with file location and context.

**User request examples:**
- "Find all TODOs in the project"
- "Show me FIXME comments"
- "What technical debt exists in controllers?"

---

## Step 1: Define the Tool Schema

Edit `app/services/ai_agent_service.rb` and add to `build_tool_definitions`:

```ruby
def build_tool_definitions
  [
    # ... existing tools ...
    
    # New tool for finding TODO comments
    {
      type: "function",
      function: {
        name: "find_todos",
        description: "Find TODO, FIXME, HACK, and NOTE comments across the codebase with file locations and context",
        parameters: {
          type: "object",
          properties: {
            comment_types: {
              type: "array",
              description: "Types of comments to find (e.g., ['TODO', 'FIXME'])",
              items: { type: "string" },
              default: ["TODO", "FIXME", "HACK", "NOTE"]
            },
            file_pattern: {
              type: "string",
              description: "Limit search to files matching pattern (e.g., '**/*.rb' for Ruby files only)",
              default: "**/*.{rb,js,ts,jsx,tsx,erb,css,html}"
            },
            include_context: {
              type: "boolean",
              description: "Include 2 lines before/after each comment for context",
              default: true
            }
          },
          required: []
        }
      }
    }
  ]
end
```

**Why these parameters?**
- `comment_types`: Flexible - user might only want TODOs, not FIXMEs
- `file_pattern`: Allows filtering to specific file types
- `include_context`: Context helps understand what the TODO is about

---

## Step 2: Add Handler Route

In the same file, find `handle_tool_call` and add:

```ruby
def handle_tool_call(tool_name, arguments)
  case tool_name
  # ... existing cases ...
  
  when 'find_todos'
    find_todos_tool(arguments)
  
  else
    { error: "Unknown tool: #{tool_name}" }
  end
rescue StandardError => e
  { error: e.message, backtrace: e.backtrace.first(5) }
end
```

---

## Step 3: Implement the Tool

Edit `app/services/ai_agent_service_tools.rb` and add:

```ruby
module AiAgentServiceTools
  # ... existing methods ...
  
  def find_todos_tool(arguments)
    project = conversation.project
    return { error: 'No project associated' } unless project
    
    comment_types = arguments['comment_types'] || ['TODO', 'FIXME', 'HACK', 'NOTE']
    file_pattern = arguments['file_pattern'] || '**/*.{rb,js,ts,jsx,tsx,erb,css,html}'
    include_context = arguments.fetch('include_context', true)
    
    # Build regex pattern: matches "TODO:", "# FIXME:", "// HACK:", etc.
    # Pattern: optional comment chars, then keyword, then optional colon and message
    regex_pattern = /(?:\/\/|#|\/\*|\*|<!--)\s*(#{comment_types.join('|')})[\s:]+(.+?)(?:\*\/|-->|$)/i
    
    # Get all files matching pattern
    files = Dir.glob(File.join(project.absolute_path, file_pattern))
      .reject { |f| File.directory?(f) }
      .map { |f| f.sub("#{project.absolute_path}/", '') }
    
    todos = []
    
    files.each do |file_path|
      full_path = File.join(project.absolute_path, file_path)
      next unless File.exist?(full_path)
      
      begin
        lines = File.readlines(full_path)
        
        lines.each_with_index do |line, index|
          if match = line.match(regex_pattern)
            comment_type = match[1].upcase
            message = match[2].strip
            line_number = index + 1
            
            context_lines = if include_context
              {
                before: lines[[index - 2, 0].max...[index, 0].max].join,
                after: lines[[index + 1, lines.length - 1].min..[index + 2, lines.length - 1].min].join
              }
            else
              nil
            end
            
            todos << {
              type: comment_type,
              message: message,
              file: file_path,
              line: line_number,
              full_line: line.strip,
              context: context_lines
            }
          end
        end
      rescue StandardError => e
        # Skip files that can't be read (binary files, encoding issues, etc.)
        next
      end
    end
    
    # Group by type for better organization
    grouped = todos.group_by { |t| t[:type] }
    
    {
      total_count: todos.length,
      by_type: grouped.transform_values(&:count),
      todos: todos.first(100), # Limit to 100 to prevent overwhelming output
      truncated: todos.length > 100,
      files_searched: files.length
    }
  rescue StandardError => e
    { error: e.message, backtrace: e.backtrace.first(5) }
  end
end
```

**Implementation highlights:**
- Regex handles different comment styles: `//`, `#`, `/* */`, `<!-- -->`
- Case-insensitive matching (TODO vs todo)
- Context includes 2 lines before/after
- Handles file reading errors gracefully
- Limits output to 100 todos (prevents UI overload)
- Returns grouped counts for quick overview

---

## Step 4: Write Tests

Create or edit `spec/services/ai_agent_service_tools_spec.rb`:

```ruby
RSpec.describe AiAgentServiceTools do
  let(:project) { create(:coding_project, name: 'test-project') }
  let(:conversation) { create(:conversation, project: project) }
  let(:service) { AiAgentService.new(conversation: conversation, prompt: '', stream_name: 'test') }
  
  describe '#find_todos_tool' do
    let(:temp_dir) { Dir.mktmpdir }
    
    before do
      allow(project).to receive(:absolute_path).and_return(temp_dir)
    end
    
    after do
      FileUtils.rm_rf(temp_dir)
    end
    
    context 'with Ruby file containing TODOs' do
      before do
        File.write(File.join(temp_dir, 'test.rb'), <<~RUBY)
          class User
            # TODO: Add email validation
            def create
              # FIXME: This should use a service
              User.create(params)
            end
            
            # HACK: Temporary workaround for bug #123
            def process
              # This is just a regular comment
              do_something
            end
          end
        RUBY
      end
      
      it 'finds all TODO comments' do
        result = service.send(:find_todos_tool, {})
        
        expect(result[:total_count]).to eq(3)
        expect(result[:by_type]).to include('TODO' => 1, 'FIXME' => 1, 'HACK' => 1)
        expect(result[:todos].first[:file]).to eq('test.rb')
        expect(result[:todos].first[:type]).to eq('TODO')
        expect(result[:todos].first[:message]).to eq('Add email validation')
      end
      
      it 'filters by comment type' do
        result = service.send(:find_todos_tool, { 'comment_types' => ['TODO'] })
        
        expect(result[:total_count]).to eq(1)
        expect(result[:todos].first[:type]).to eq('TODO')
      end
      
      it 'includes context when requested' do
        result = service.send(:find_todos_tool, { 'include_context' => true })
        
        first_todo = result[:todos].first
        expect(first_todo[:context]).to be_present
        expect(first_todo[:context][:before]).to be_present
        expect(first_todo[:context][:after]).to be_present
      end
      
      it 'excludes context when not requested' do
        result = service.send(:find_todos_tool, { 'include_context' => false })
        
        expect(result[:todos].first[:context]).to be_nil
      end
    end
    
    context 'with JavaScript file containing TODOs' do
      before do
        File.write(File.join(temp_dir, 'test.js'), <<~JS)
          // TODO: Refactor this function
          function process() {
            // FIXME: Memory leak here
            const data = fetchData();
          }
        JS
      end
      
      it 'finds TODOs in JS files' do
        result = service.send(:find_todos_tool, { 'file_pattern' => '**/*.js' })
        
        expect(result[:total_count]).to eq(2)
        expect(result[:todos].first[:file]).to eq('test.js')
      end
    end
    
    context 'with file pattern filter' do
      before do
        File.write(File.join(temp_dir, 'test.rb'), '# TODO: Ruby todo')
        File.write(File.join(temp_dir, 'test.js'), '// TODO: JS todo')
      end
      
      it 'filters to Ruby files only' do
        result = service.send(:find_todos_tool, { 'file_pattern' => '**/*.rb' })
        
        expect(result[:total_count]).to eq(1)
        expect(result[:todos].first[:file]).to eq('test.rb')
      end
    end
    
    context 'without project' do
      let(:conversation) { create(:conversation, project: nil) }
      
      it 'returns error' do
        result = service.send(:find_todos_tool, {})
        expect(result[:error]).to eq('No project associated')
      end
    end
    
    context 'with many TODOs' do
      before do
        content = (1..150).map { |i| "# TODO: Task #{i}" }.join("\n")
        File.write(File.join(temp_dir, 'test.rb'), content)
      end
      
      it 'limits output to 100 items' do
        result = service.send(:find_todos_tool, {})
        
        expect(result[:total_count]).to eq(150)
        expect(result[:todos].length).to eq(100)
        expect(result[:truncated]).to be true
      end
    end
  end
end
```

---

## Step 5: Run Tests

```bash
# Run just this test
bundle exec rspec spec/services/ai_agent_service_tools_spec.rb -e "find_todos_tool"

# Expected output:
# find_todos_tool
#   with Ruby file containing TODOs
#     finds all TODO comments
#     filters by comment type
#     includes context when requested
#     excludes context when not requested
#   with JavaScript file containing TODOs
#     finds TODOs in JS files
#   with file pattern filter
#     filters to Ruby files only
#   without project
#     returns error
#   with many TODOs
#     limits output to 100 items
#
# Finished in 0.15 seconds (files took 2.5 seconds to load)
# 8 examples, 0 failures
```

---

## Step 6: Update Documentation

Edit `TOOL_CAPABILITIES.md`:

```markdown
### Level 7.5: Technical Debt Tracking (NEW)
**Tools Implemented:**
- `find_todos`: Find TODO/FIXME/HACK/NOTE comments
  - Supports multiple comment styles (Ruby, JS, HTML)
  - Configurable comment types to search
  - File pattern filtering
  - Contextual lines before/after each comment
  - Grouped by type with counts
  - Returns file path, line number, and message
```

---

## Step 7: Manual Testing

Start the app and test:

```bash
bin/dev
```

Navigate to a conversation and ask:

**Test 1: Basic usage**
```
User: "Find all TODOs in the project"

AI: [Calls find_todos tool]

Result:
{
  "total_count": 12,
  "by_type": {
    "TODO": 8,
    "FIXME": 3,
    "HACK": 1
  },
  "todos": [
    {
      "type": "TODO",
      "message": "Add email validation",
      "file": "app/models/user.rb",
      "line": 15,
      "full_line": "# TODO: Add email validation"
    },
    ...
  ]
}

AI: "I found 12 technical debt items: 8 TODOs, 3 FIXMEs, and 1 HACK..."
```

**Test 2: Filtered search**
```
User: "Show me only FIXME comments in controllers"

AI: [Calls find_todos with comment_types=['FIXME'], file_pattern='app/controllers/**/*.rb']

Result:
{
  "total_count": 3,
  "todos": [...]
}
```

---

## Step 8: Verify Tool Execution in UI

When the AI calls the tool, you should see:

1. **Tool call indicator** (animated card):
   ```
   🔧 Running find_todos
   {
     "comment_types": ["TODO", "FIXME", "HACK", "NOTE"],
     "file_pattern": "**/*.{rb,js,ts,jsx,tsx,erb,css,html}",
     "include_context": true
   }
   ```

2. **Tool result** (success card):
   ```
   ✅ find_todos completed
   {
     "total_count": 12,
     "by_type": { "TODO": 8, "FIXME": 3, "HACK": 1 },
     ...
   }
   ```

3. **AI response** incorporating the results

---

## What We Learned

### Key Takeaways

1. **Tool definition is crucial** - Clear description helps LLM decide when to call it
2. **Parameter design matters** - Flexible parameters = more use cases
3. **Error handling is essential** - Gracefully handle missing files, encoding issues
4. **Output limits prevent problems** - 100-item limit prevents overwhelming UI
5. **Context is valuable** - Including surrounding lines helps understand TODOs
6. **Testing is non-negotiable** - Comprehensive tests catch edge cases

### Common Patterns

#### Pattern 1: Project Validation
```ruby
def my_tool(arguments)
  project = conversation.project
  return { error: 'No project associated' } unless project
  # ... rest of implementation
end
```

#### Pattern 2: Parameter Defaults
```ruby
comment_types = arguments['comment_types'] || ['TODO', 'FIXME']
include_context = arguments.fetch('include_context', true)
```

#### Pattern 3: Result Limiting
```ruby
{
  todos: todos.first(100),
  truncated: todos.length > 100,
  total_count: todos.length
}
```

#### Pattern 4: File Operations with Error Handling
```ruby
files.each do |file_path|
  begin
    lines = File.readlines(full_path)
    # ... process lines
  rescue StandardError => e
    next  # Skip problematic files
  end
end
```

#### Pattern 5: Structured Return Values
```ruby
{
  total_count: 12,           # Summary stat
  by_type: { ... },          # Grouped data
  todos: [...],              # Actual results
  truncated: false,          # Metadata
  files_searched: 45         # Context
}
```

---

## Real-World Usage Examples

### Example 1: Sprint Planning

**User**: "Find all TODOs and FIXMEs to prioritize for next sprint"

**AI Response**:
```
I found 15 items that need attention:

High Priority (FIXME - 5 items):
• app/controllers/payments_controller.rb:45 - "Security issue with token validation"
• app/services/payment_processor.rb:123 - "Race condition in refund logic"
...

Medium Priority (TODO - 10 items):
• app/models/user.rb:78 - "Add email validation"
• app/views/dashboard/show.html.erb:12 - "Improve loading state"
...

Would you like me to create GitHub issues for these?
```

### Example 2: Code Review

**User**: "Are there any HACKs in the authentication system?"

**AI Response**:
```
I found 1 HACK in the authentication code:

app/controllers/sessions_controller.rb:34
"Temporary bypass for admin users - REMOVE BEFORE PRODUCTION"

Context:
32:   def create
33:     user = User.find_by(email: params[:email])
34:     # HACK: Temporary bypass for admin users - REMOVE BEFORE PRODUCTION
35:     if user&.admin? || user&.authenticate(params[:password])
36:       session[:user_id] = user.id

⚠️ This is a security risk and should be addressed immediately.
```

### Example 3: Technical Debt Report

**User**: "Generate a technical debt report for the frontend"

**AI Response**:
```
Frontend Technical Debt Summary:

TODOs (15 items):
• Performance optimizations: 5
• UI improvements: 7
• Accessibility: 3

FIXMEs (3 items):
• app/javascript/controllers/chart_controller.ts:89 - Memory leak in chart updates
• app/javascript/utils/api.ts:45 - Error handling incomplete
• app/views/shared/_modal.html.erb:12 - Focus trap broken

Recommended Actions:
1. Fix memory leak (critical)
2. Complete error handling (high)
3. Address accessibility issues (medium)

Estimated effort: 2-3 days
```

---

## Extending the Tool

### Ideas for Enhancement

1. **Priority Detection**: Parse "TODO(P1)" vs "TODO(P3)"
2. **Assignee Tracking**: Parse "TODO(@username)"
3. **Due Dates**: Parse "TODO(before-2024-12-31)"
4. **GitHub Issue Integration**: Auto-create issues from TODOs
5. **Ignore Patterns**: Skip vendor/, node_modules/
6. **Age Tracking**: Use git blame to find old TODOs
7. **Categorization**: Group by module/feature area

### Example: Adding Priority Detection

```ruby
# Match patterns like: TODO(P1): High priority task
regex_pattern = /(?:\/\/|#|\/\*)\s*(#{comment_types.join('|')})(?:\(([^)]+)\))?[\s:]+(.+?)(?:\*\/|$)/i

if match = line.match(regex_pattern)
  comment_type = match[1].upcase
  priority = match[2]&.strip # "P1", "@alice", etc.
  message = match[3].strip
  
  todos << {
    type: comment_type,
    priority: priority,
    message: message,
    # ...
  }
end
```

---

## Conclusion

You now have a fully functional `find_todos` tool! This example demonstrates:

- Complete tool lifecycle (definition → implementation → testing → documentation)
- Real-world considerations (error handling, output limits, context)
- Practical usage patterns
- Testing strategies
- Extension possibilities

Use this as a template for adding your own custom tools. The same pattern applies whether you're adding a code formatter, linter integration, deployment tool, or any other capability.

**Next steps:**
1. Commit this new tool: `git add . && git commit -m "Add find_todos tool for technical debt tracking"`
2. Try adding your own tool using this example as a guide
3. Share your custom tools with the team!

Happy tool building! 🛠️

# AI Tool Maintenance Guide

## How to Update This App with Latest Tools

This guide explains how to add, update, or remove AI tools when ClackyAI platform evolves or when you want to add custom capabilities to your AI coding assistant.

---

## Table of Contents

1. [Understanding the Tool Architecture](#understanding-the-tool-architecture)
2. [Adding a New Tool (Step-by-Step)](#adding-a-new-tool-step-by-step)
3. [Updating Existing Tools](#updating-existing-tools)
4. [Removing Tools](#removing-tools)
5. [Testing Your Changes](#testing-your-changes)
6. [Best Practices](#best-practices)
7. [Common Pitfalls](#common-pitfalls)

---

## Understanding the Tool Architecture

### How Tools Work

The AI assistant uses OpenAI's function calling feature. Here's the flow:

```
User Message → LLM → Tool Call Request → Tool Handler → Result → LLM → Response
```

### Key Files

| File | Purpose |
|------|---------|
| `app/services/ai_agent_service.rb` | Main service - defines tool schemas & routing |
| `app/services/ai_agent_service_tools.rb` | Tool implementations (actual logic) |
| `app/jobs/llm_stream_job.rb` | Executes tools and streams results via ActionCable |
| `app/javascript/controllers/chat_controller.ts` | Displays tool execution in UI |
| `spec/services/ai_agent_service_tools_spec.rb` | Tool tests |
| `TOOL_CAPABILITIES.md` | Documentation of all available tools |

### Tool Components

Every tool has 3 parts:

1. **Tool Definition** (OpenAI function schema) - Tells the LLM what the tool does
2. **Tool Handler** (Router) - Routes the tool call to the implementation
3. **Tool Implementation** (Business logic) - Does the actual work

---

## Adding a New Tool (Step-by-Step)

### Example: Adding a "format_code" Tool

Let's add a tool that auto-formats Ruby/JavaScript code using Rubocop/ESLint.

#### Step 1: Define the Tool Schema

Edit `app/services/ai_agent_service.rb`, find the `build_tool_definitions` method, and add your tool definition:

```ruby
def build_tool_definitions
  [
    # ... existing tools ...
    
    # Your new tool
    {
      type: "function",
      function: {
        name: "format_code",
        description: "Auto-format code files using language-specific formatters (Rubocop for Ruby, ESLint for JS/TS)",
        parameters: {
          type: "object",
          properties: {
            path: {
              type: "string",
              description: "Path to file to format"
            },
            fix_issues: {
              type: "boolean",
              description: "Also fix auto-correctable issues (not just formatting)",
              default: false
            }
          },
          required: ["path"]
        }
      }
    }
  ]
end
```

**Schema Guidelines:**
- `name`: Lowercase, snake_case, descriptive
- `description`: Clear explanation of what it does (LLM uses this to decide when to call it)
- `parameters`: JSON Schema format
- `required`: Array of required parameter names
- Use `default` for optional parameters

#### Step 2: Add Tool Handler Route

In the same file, find the `handle_tool_call` method and add your routing:

```ruby
def handle_tool_call(tool_name, arguments)
  case tool_name
  # ... existing cases ...
  
  when 'format_code'
    format_code_tool(arguments)
  
  else
    { error: "Unknown tool: #{tool_name}" }
  end
rescue StandardError => e
  { error: e.message, backtrace: e.backtrace.first(5) }
end
```

#### Step 3: Implement the Tool Logic

Edit `app/services/ai_agent_service_tools.rb` and add your implementation:

```ruby
module AiAgentServiceTools
  # ... existing methods ...
  
  def format_code_tool(arguments)
    file_path = arguments['path']
    fix_issues = arguments['fix_issues'] || false
    project = conversation.project
    return { error: 'No project associated' } unless project
    
    full_path = File.join(project.absolute_path, file_path)
    return { error: "File not found: #{file_path}" } unless File.exist?(full_path)
    
    # Determine formatter based on file extension
    extension = File.extname(file_path)
    
    case extension
    when '.rb'
      command = fix_issues ? "rubocop -A #{file_path}" : "rubocop -x #{file_path}"
    when '.js', '.ts', '.jsx', '.tsx'
      command = fix_issues ? "npx eslint --fix #{file_path}" : "npx eslint --fix-dry-run #{file_path}"
    else
      return { error: "Unsupported file type: #{extension}" }
    end
    
    # Execute formatter
    output = `cd #{project.absolute_path} && #{command} 2>&1`
    exit_code = $?.exitstatus
    
    {
      success: exit_code.zero?,
      path: file_path,
      formatter: extension == '.rb' ? 'rubocop' : 'eslint',
      output: output,
      fixed: fix_issues
    }
  rescue StandardError => e
    { error: e.message, backtrace: e.backtrace.first(5) }
  end
end
```

**Implementation Guidelines:**
- Always validate project existence
- Always check file/path existence
- Return structured hashes (JSON-serializable)
- Include error handling with backtrace
- Use project.absolute_path for file operations
- Return success/failure indicators

#### Step 4: Write Tests

Create or edit `spec/services/ai_agent_service_tools_spec.rb`:

```ruby
RSpec.describe AiAgentServiceTools do
  let(:project) { create(:coding_project, name: 'test-project') }
  let(:conversation) { create(:conversation, project: project) }
  let(:service) { AiAgentService.new(conversation: conversation, prompt: '', stream_name: 'test') }
  
  describe '#format_code_tool' do
    context 'with valid Ruby file' do
      before do
        allow(project).to receive(:absolute_path).and_return('/tmp/test-project')
        allow(File).to receive(:exist?).and_return(true)
      end
      
      it 'formats code using rubocop' do
        allow(service).to receive(:`).and_return("1 file inspected, no offenses detected\n")
        allow($?).to receive(:exitstatus).and_return(0)
        
        result = service.send(:format_code_tool, { 'path' => 'app/models/user.rb', 'fix_issues' => false })
        
        expect(result[:success]).to be true
        expect(result[:formatter]).to eq('rubocop')
        expect(result[:path]).to eq('app/models/user.rb')
      end
    end
    
    context 'with unsupported file type' do
      it 'returns error' do
        result = service.send(:format_code_tool, { 'path' => 'README.md' })
        expect(result[:error]).to include('Unsupported file type')
      end
    end
    
    context 'without project' do
      let(:conversation) { create(:conversation, project: nil) }
      
      it 'returns error' do
        result = service.send(:format_code_tool, { 'path' => 'test.rb' })
        expect(result[:error]).to eq('No project associated')
      end
    end
  end
end
```

#### Step 5: Update Documentation

Edit `TOOL_CAPABILITIES.md` and add your tool:

```markdown
### Level X: Code Formatting (NEW)
**Tools Implemented:**
- `format_code`: Auto-format code files
  - Supports Ruby (Rubocop) and JavaScript/TypeScript (ESLint)
  - Auto-fix mode for correctable issues
  - Returns formatted output and success status
```

#### Step 6: Test & Verify

```bash
# Run tests
bundle exec rspec spec/services/ai_agent_service_tools_spec.rb

# Start the app
bin/dev

# Test in browser:
# Navigate to a conversation and ask:
# "Format the file app/models/user.rb"
```

The AI should now be able to call your `format_code` tool!

---

## Updating Existing Tools

### Scenario: Add New Parameter to Existing Tool

Let's say you want to add a `line_limit` parameter to the `read_file` tool.

#### Step 1: Update Tool Definition

```ruby
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
          description: "Relative path to the file"
        },
        line_limit: {  # NEW PARAMETER
          type: "integer",
          description: "Maximum number of lines to read (omit for full file)",
          default: nil
        }
      },
      required: ["path"]
    }
  }
}
```

#### Step 2: Update Implementation

```ruby
def read_file_tool(arguments)
  file_path = arguments['path']
  line_limit = arguments['line_limit']  # NEW
  project = conversation.project
  return { error: 'No project associated' } unless project

  content = project.read_file(file_path)
  return { error: "File not found: #{file_path}" } if content.nil?

  # NEW: Apply line limit if specified
  if line_limit && line_limit > 0
    lines = content.lines
    content = lines.first(line_limit).join
    truncated = lines.length > line_limit
  else
    truncated = false
  end

  {
    path: file_path,
    content: content,
    size: content.bytesize,
    truncated: truncated,  # NEW
    total_lines: content.lines.length  # NEW
  }
end
```

#### Step 3: Update Tests

```ruby
describe '#read_file_tool' do
  # ... existing tests ...
  
  context 'with line limit' do
    it 'returns only specified number of lines' do
      allow(project).to receive(:read_file).and_return("line1\nline2\nline3\nline4\n")
      
      result = service.send(:read_file_tool, { 'path' => 'test.txt', 'line_limit' => 2 })
      
      expect(result[:content]).to eq("line1\nline2\n")
      expect(result[:truncated]).to be true
    end
  end
end
```

#### Step 4: Document Changes

Update `TOOL_CAPABILITIES.md` to mention the new parameter.

---

## Removing Tools

### When to Remove Tools

- Tool is deprecated or replaced
- Tool has security risks
- Tool is unused and adds complexity

### How to Remove

1. **Remove tool definition** from `build_tool_definitions` in `ai_agent_service.rb`
2. **Remove handler route** from `handle_tool_call` in `ai_agent_service.rb`
3. **Remove implementation** from `ai_agent_service_tools.rb`
4. **Remove tests** from `spec/services/ai_agent_service_tools_spec.rb`
5. **Update documentation** in `TOOL_CAPABILITIES.md`

Example:

```ruby
# Before
def build_tool_definitions
  [
    { type: "function", function: { name: "old_tool", ... } },
    { type: "function", function: { name: "new_tool", ... } }
  ]
end

# After (removed old_tool)
def build_tool_definitions
  [
    { type: "function", function: { name: "new_tool", ... } }
  ]
end
```

---

## Testing Your Changes

### Run Full Test Suite

```bash
rake test
```

### Test Specific Tool

```bash
bundle exec rspec spec/services/ai_agent_service_tools_spec.rb -e "format_code_tool"
```

### Manual Testing Checklist

1. ✅ Start app: `bin/dev`
2. ✅ Create/open conversation
3. ✅ Ask AI to use your tool: "Format the file app/models/user.rb"
4. ✅ Verify tool execution appears in UI (animated tool card)
5. ✅ Verify tool result is correct
6. ✅ Check browser console for errors
7. ✅ Check Rails logs: `tail -f log/development.log`

---

## Best Practices

### Tool Design Principles

1. **Single Responsibility**: Each tool does ONE thing well
2. **Clear Descriptions**: LLM uses descriptions to decide when to call tools
3. **Fail Fast**: Return errors immediately, don't try to "fix" invalid inputs
4. **Structured Output**: Return consistent JSON structures
5. **Error Context**: Include helpful error messages and backtrace

### Parameter Naming

```ruby
# ✅ GOOD - Descriptive, matches conventions
{
  path: "string",
  max_depth: "integer",
  include_hidden: "boolean"
}

# ❌ BAD - Unclear, inconsistent
{
  p: "string",
  depth: "integer",
  hidden: "boolean"
}
```

### Return Values

```ruby
# ✅ GOOD - Structured, clear success/failure
{
  success: true,
  path: "app/models/user.rb",
  lines_changed: 5,
  formatter: "rubocop"
}

# ❌ BAD - Unclear status, missing context
{
  result: "ok"
}
```

### Error Handling

```ruby
# ✅ GOOD - Specific error with context
def my_tool(arguments)
  return { error: 'No project associated' } unless project
  return { error: "File not found: #{path}" } unless File.exist?(full_path)
  
  # ... implementation ...
rescue Errno::EACCES => e
  { error: "Permission denied: #{e.message}" }
rescue StandardError => e
  { error: e.message, backtrace: e.backtrace.first(5) }
end

# ❌ BAD - Generic error, no context
def my_tool(arguments)
  # ... implementation ...
rescue
  { error: "Something went wrong" }
end
```

---

## Common Pitfalls

### ❌ Forgetting to Add Handler Route

```ruby
# You added tool definition but forgot this:
def handle_tool_call(tool_name, arguments)
  case tool_name
  when 'new_tool'  # ← ADD THIS!
    new_tool_implementation(arguments)
  end
end
```

**Symptom**: AI tries to call tool but gets "Unknown tool" error

---

### ❌ Wrong Parameter Types

```ruby
# Tool definition says "integer" but implementation expects string
parameters: {
  max_depth: { type: "integer" }  # LLM sends: 5
}

def my_tool(arguments)
  max_depth = arguments['max_depth']  # receives: 5 (integer)
  if max_depth == "5"  # ❌ This will fail!
end
```

**Fix**: Match types in definition and implementation

---

### ❌ Not Handling Missing Parameters

```ruby
# ❌ BAD - Will crash if 'optional_param' not provided
def my_tool(arguments)
  value = arguments['optional_param'].upcase
end

# ✅ GOOD - Use || for defaults
def my_tool(arguments)
  value = (arguments['optional_param'] || 'default').upcase
end
```

---

### ❌ Returning Non-Serializable Objects

```ruby
# ❌ BAD - ActiveRecord objects can't be serialized to JSON
def my_tool(arguments)
  { user: User.first }
end

# ✅ GOOD - Return hashes/arrays/primitives
def my_tool(arguments)
  user = User.first
  { user: { id: user.id, name: user.name, email: user.email } }
end
```

---

### ❌ Not Testing Error Cases

```ruby
# ✅ GOOD - Test both success and failure
it 'returns result on success' do
  # ... happy path test ...
end

it 'returns error when file not found' do
  # ... error test ...
end

it 'returns error when no project' do
  # ... error test ...
end
```

---

## Syncing with ClackyAI Platform Updates

### When ClackyAI Releases New Tools

If ClackyAI platform adds new tools, you can integrate them:

1. **Check ClackyAI Documentation** (https://docs.clacky.ai/)
2. **Review Tool Specification** (parameters, return values, behavior)
3. **Follow "Adding a New Tool" Guide** (above)
4. **Test Thoroughly** (your implementation may differ from platform)

### Keeping Tool Definitions Consistent

If you want your local app to match ClackyAI platform exactly:

1. Export tool definitions from platform (if API available)
2. Compare with your `build_tool_definitions` method
3. Update parameter names, descriptions, types to match
4. Test with same inputs to ensure compatible behavior

---

## Example: Real Tool Evolution

### Evolution of `read_file` Tool

**Version 1 (Basic):**
```ruby
def read_file_tool(arguments)
  content = project.read_file(arguments['path'])
  { content: content }
end
```

**Version 2 (Added Metadata):**
```ruby
def read_file_tool(arguments)
  content = project.read_file(arguments['path'])
  {
    path: arguments['path'],
    content: content,
    size: content.bytesize
  }
end
```

**Version 3 (Added Error Handling):**
```ruby
def read_file_tool(arguments)
  return { error: 'No project' } unless project
  
  content = project.read_file(arguments['path'])
  return { error: 'File not found' } if content.nil?
  
  {
    path: arguments['path'],
    content: content,
    size: content.bytesize
  }
end
```

**Version 4 (Added Line Limit):**
```ruby
def read_file_tool(arguments)
  return { error: 'No project' } unless project
  
  content = project.read_file(arguments['path'])
  return { error: 'File not found' } if content.nil?
  
  # NEW: Line limit support
  if (limit = arguments['line_limit'])
    lines = content.lines
    content = lines.first(limit).join
    truncated = lines.length > limit
  end
  
  {
    path: arguments['path'],
    content: content,
    size: content.bytesize,
    truncated: truncated || false
  }
end
```

Notice how each version:
- Maintains backward compatibility
- Adds new features incrementally
- Improves error handling
- Adds more metadata

---

## Quick Reference Checklist

### Adding a New Tool

- [ ] Add tool definition to `build_tool_definitions`
- [ ] Add handler route to `handle_tool_call`
- [ ] Implement tool method in `ai_agent_service_tools.rb`
- [ ] Write tests in `spec/services/ai_agent_service_tools_spec.rb`
- [ ] Update `TOOL_CAPABILITIES.md`
- [ ] Run `rake test`
- [ ] Manual test in browser

### Updating a Tool

- [ ] Update tool definition (if parameters changed)
- [ ] Update implementation
- [ ] Update tests (add new test cases)
- [ ] Update documentation
- [ ] Run `rake test`
- [ ] Manual test in browser

### Removing a Tool

- [ ] Remove from `build_tool_definitions`
- [ ] Remove from `handle_tool_call`
- [ ] Remove implementation
- [ ] Remove tests
- [ ] Update documentation
- [ ] Run `rake test`

---

## Getting Help

### Debug Tool Calls

Check Rails logs to see tool execution:

```bash
tail -f log/development.log | grep "Tool call"
```

### Inspect Tool Results

In browser console:

```javascript
// Chat controller logs tool calls/results
// Check Console tab for tool execution details
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "Unknown tool" error | Add handler route in `handle_tool_call` |
| Tool not being called | Check tool description clarity |
| Wrong parameter type | Match types in definition & implementation |
| JSON serialization error | Return plain hashes, not ActiveRecord objects |
| Test failures | Check project/file mocking in tests |

---

## Advanced Topics

### Tool Chaining

Tools can call other tools internally:

```ruby
def complex_tool(arguments)
  # Call another tool
  files = list_files_tool({ 'pattern' => '**/*.rb' })
  
  # Process results
  files[:files].map do |file|
    read_file_tool({ 'path' => file })
  end
end
```

### Streaming Tool Results

Tools execute synchronously, but results stream via ActionCable:

```ruby
# app/jobs/llm_stream_job.rb broadcasts:
ActionCable.server.broadcast(@stream_name, {
  type: 'tool_call',
  data: { tool_name: name, arguments: args }
})

# Then broadcasts result:
ActionCable.server.broadcast(@stream_name, {
  type: 'tool_result',
  data: { tool_name: name, result: result }
})
```

### Tool Permissions

Add permission checks to tools:

```ruby
def sensitive_tool(arguments)
  return { error: 'Unauthorized' } unless conversation.user&.admin?
  
  # ... implementation ...
end
```

---

## Conclusion

This guide covers everything you need to maintain and evolve your AI coding assistant's tool capabilities. Remember:

1. **Follow the patterns** established by existing tools
2. **Test thoroughly** (unit tests + manual testing)
3. **Document clearly** (help future you!)
4. **Keep it simple** (one tool = one responsibility)

Happy coding! 🚀

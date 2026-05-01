# Tool Update Quick Start

**Quick reference for updating your AI coding assistant with new tools.**

---

## 📚 Full Documentation

- **[Tool Maintenance Guide](TOOL_MAINTENANCE_GUIDE.md)** - Complete guide with detailed explanations
- **[Example: Adding find_todos Tool](EXAMPLE_NEW_TOOL.md)** - Real implementation with tests
- **[Tool Capabilities](../TOOL_CAPABILITIES.md)** - All current tools (Level 1-10)

---

## ⚡ TL;DR: Adding a New Tool

### 1. Define Tool Schema
**File**: `app/services/ai_agent_service.rb` → `build_tool_definitions`

```ruby
{
  type: "function",
  function: {
    name: "your_tool_name",
    description: "Clear description for LLM",
    parameters: {
      type: "object",
      properties: {
        param1: { type: "string", description: "..." },
        param2: { type: "boolean", default: false }
      },
      required: ["param1"]
    }
  }
}
```

### 2. Add Handler Route
**File**: `app/services/ai_agent_service.rb` → `handle_tool_call`

```ruby
when 'your_tool_name'
  your_tool_name_tool(arguments)
```

### 3. Implement Tool
**File**: `app/services/ai_agent_service_tools.rb`

```ruby
def your_tool_name_tool(arguments)
  project = conversation.project
  return { error: 'No project associated' } unless project
  
  # Your implementation
  
  { success: true, result: "..." }
rescue StandardError => e
  { error: e.message, backtrace: e.backtrace.first(5) }
end
```

### 4. Write Tests
**File**: `spec/services/ai_agent_service_tools_spec.rb`

```ruby
describe '#your_tool_name_tool' do
  it 'works correctly' do
    result = service.send(:your_tool_name_tool, { 'param1' => 'value' })
    expect(result[:success]).to be true
  end
  
  context 'without project' do
    it 'returns error' do
      # Test error cases
    end
  end
end
```

### 5. Run Tests & Commit
```bash
bundle exec rspec spec/services/ai_agent_service_tools_spec.rb
git add .
git commit -m "Add your_tool_name tool"
```

---

## 🔄 Updating Existing Tool

1. **Update definition** (if parameters changed)
2. **Update implementation**
3. **Update tests** (add new test cases)
4. Run `rake test`

---

## ❌ Removing Tool

1. Remove from `build_tool_definitions`
2. Remove from `handle_tool_call`
3. Remove implementation
4. Remove tests
5. Update documentation

---

## 📋 Checklist

- [ ] Tool definition added
- [ ] Handler route added
- [ ] Implementation complete
- [ ] Tests written (happy path + error cases)
- [ ] Tests passing (`rake test`)
- [ ] Manual testing in browser
- [ ] Documentation updated
- [ ] Changes committed

---

## 🛠️ Tool Pattern Template

```ruby
# Definition
{
  type: "function",
  function: {
    name: "ACTION_target",  # e.g., find_todos, format_code
    description: "Verb + what + why/when",
    parameters: {
      type: "object",
      properties: {
        required_param: { type: "string", description: "..." },
        optional_param: { type: "boolean", default: false }
      },
      required: ["required_param"]
    }
  }
}

# Implementation
def action_target_tool(arguments)
  # 1. Validate project
  project = conversation.project
  return { error: 'No project associated' } unless project
  
  # 2. Extract parameters
  required_param = arguments['required_param']
  optional_param = arguments.fetch('optional_param', false)
  
  # 3. Validate inputs
  return { error: 'Invalid input' } unless valid?(required_param)
  
  # 4. Perform action
  result = do_something(required_param, optional_param)
  
  # 5. Return structured result
  {
    success: true,
    data: result,
    metadata: { count: result.length }
  }
rescue StandardError => e
  { error: e.message, backtrace: e.backtrace.first(5) }
end
```

---

## 🚨 Common Mistakes

| ❌ Don't | ✅ Do |
|---------|-------|
| Forget handler route | Add to `handle_tool_call` |
| Return ActiveRecord objects | Return plain hashes |
| Use wrong parameter types | Match definition types |
| Skip error handling | Wrap in begin/rescue |
| Ignore test failures | Fix until all pass |
| Skip manual testing | Test in browser |

---

## 💡 Best Practices

1. **Clear descriptions** - LLM uses these to decide when to call tools
2. **Validate early** - Check project, params, file existence upfront
3. **Return structured data** - `{ success, data, metadata }` format
4. **Limit output** - Prevent overwhelming UI (max 100 items)
5. **Include context** - Help LLM understand results
6. **Error details** - Include backtrace for debugging

---

## 🔍 Debugging

### Tool not being called?
- Check description clarity
- Verify tool is in `build_tool_definitions`
- Test by explicitly asking: "Use the your_tool_name tool to..."

### "Unknown tool" error?
- Add handler route to `handle_tool_call`

### Parameter errors?
- Match types in definition and implementation
- Use `.fetch()` for optional params with defaults

### Test failures?
- Check project mocking: `allow(project).to receive(:absolute_path)`
- Verify file existence mocking: `allow(File).to receive(:exist?)`

---

## 📞 Getting Help

1. **Read full guide**: [TOOL_MAINTENANCE_GUIDE.md](TOOL_MAINTENANCE_GUIDE.md)
2. **Study example**: [EXAMPLE_NEW_TOOL.md](EXAMPLE_NEW_TOOL.md)
3. **Check existing tools**: `app/services/ai_agent_service_tools.rb`
4. **Review tests**: `spec/services/ai_agent_service_tools_spec.rb`

---

## 🎯 Quick Examples

### Simple Tool (No Parameters)
```ruby
# Definition
{ name: "get_stats", description: "Get project statistics", parameters: { type: "object", properties: {}, required: [] } }

# Implementation
def get_stats_tool(arguments)
  project = conversation.project
  return { error: 'No project' } unless project
  
  { total_files: count_files, total_lines: count_lines }
end
```

### Tool with File Operations
```ruby
def read_and_analyze_tool(arguments)
  path = arguments['path']
  project = conversation.project
  return { error: 'No project' } unless project
  
  full_path = File.join(project.absolute_path, path)
  return { error: 'File not found' } unless File.exist?(full_path)
  
  content = File.read(full_path)
  { path: path, lines: content.lines.count, size: content.bytesize }
end
```

### Tool with Shell Commands
```ruby
def run_linter_tool(arguments)
  project = conversation.project
  return { error: 'No project' } unless project
  
  output = `cd #{project.absolute_path} && rubocop 2>&1`
  exit_code = $?.exitstatus
  
  { success: exit_code.zero?, output: output, exit_code: exit_code }
end
```

---

## 🚀 Next Steps

1. **Try it yourself**: Add the `find_todos` tool from the example
2. **Customize**: Modify for your specific needs
3. **Share**: Document custom tools for your team
4. **Iterate**: Improve based on actual usage

Happy coding! 🎉

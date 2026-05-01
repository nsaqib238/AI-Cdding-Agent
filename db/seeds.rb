puts "Clearing existing data..."
CodingFile.destroy_all
Message.destroy_all
Conversation.destroy_all
CodingProject.destroy_all

puts "Creating demo coding project..."
# Create a test project directory
test_project_path = Rails.root.join('tmp', 'demo_project')
FileUtils.mkdir_p(test_project_path)

project = CodingProject.create!(
  name: "Demo Project",
  absolute_path: test_project_path.to_s,
  description: "A sample project for testing",
  status: "active"
)

puts "Creating demo files..."
# Create actual files on disk
File.write(File.join(test_project_path, 'README.md'), "# Demo Project\n\nWelcome to the demo project!")
File.write(File.join(test_project_path, 'main.rb'), "# Main Ruby file\nputs 'Hello from Demo Project!'")

# Track them in database
file1 = project.coding_files.create!(
  relative_path: "README.md",
  version: 1,
  last_modified_at: Time.current
)

file2 = project.coding_files.create!(
  relative_path: "main.rb",
  version: 1,
  last_modified_at: Time.current
)

puts "Creating demo conversation..."
conversation = project.conversations.create!(
  title: "Getting Started with Demo Project"
)

puts "Creating demo messages..."
conversation.messages.create!(
  role: "user",
  content: "Can you help me understand this project?"
)

conversation.messages.create!(
  role: "assistant",
  content: "Of course! This is a demo project with a README and a main Ruby file. The README provides project information, and main.rb contains the entry point."
)

puts "Creating blank conversation for testing..."
Conversation.create!(
  title: "Test Conversation",
  project: nil
)

puts "Seeds created successfully!"
puts "Projects: #{CodingProject.count}"
puts "Files: #{CodingFile.count}"
puts "Conversations: #{Conversation.count}"
puts "Messages: #{Message.count}"

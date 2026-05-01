FactoryBot.define do
  factory :coding_project do
    name { "Test Project" }
    description { "A test coding project" }
    absolute_path { Rails.root.join('tmp', 'test_projects', SecureRandom.hex(4)).to_s }
    status { "active" }

    after(:build) do |project|
      FileUtils.mkdir_p(project.absolute_path) unless Dir.exist?(project.absolute_path)
    end

    after(:create) do |project|
      # Create a sample file
      File.write(File.join(project.absolute_path, 'README.md'), "# #{project.name}\n\nTest project")
    end
  end
end

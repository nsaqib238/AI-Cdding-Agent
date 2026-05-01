FactoryBot.define do
  factory :coding_file do
    association :project, factory: :coding_project
    relative_path { "src/main.rb" }
    version { 1 }
    last_modified_at { Time.current }

    after(:create) do |file|
      # Create the actual file on disk
      full_path = File.join(file.project.absolute_path, file.relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, "# Sample Ruby file\nputs 'Hello World'\n")
    end
  end
end

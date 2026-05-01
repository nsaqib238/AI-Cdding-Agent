FactoryBot.define do
  factory :file_version do

    coding_file_id { 1 }
    version { 1 }
    content { "MyText" }
    size { 1 }

  end
end

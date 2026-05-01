FactoryBot.define do
  factory :conversation do

    association :project, factory: :coding_project
    title { "MyString" }

    trait :without_project do
      project { nil }
    end
  end
end

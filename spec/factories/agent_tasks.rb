FactoryBot.define do
  factory :agent_task do

    association :conversation
    status { "pending" }
    title { "MyString" }
    description { "MyText" }
    result { "MyText" }

  end
end

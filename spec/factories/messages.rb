FactoryBot.define do
  factory :message do

    association :conversation
    role { "MyString" }
    content { "MyText" }

  end
end

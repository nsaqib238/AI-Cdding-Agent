FactoryBot.define do
  factory :command_execution do

    association :conversation
    command { "MyText" }
    output { "MyText" }
    exit_code { 1 }
    status { "pending" }

  end
end

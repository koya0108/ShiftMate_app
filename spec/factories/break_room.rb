FactoryBot.define do
  factory :break_room do
    name { "休憩室A" }
    association :project
  end
end

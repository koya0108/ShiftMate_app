FactoryBot.define do
  factory :project do
    name { "テストプロジェクト" }
    association :user
  end
end

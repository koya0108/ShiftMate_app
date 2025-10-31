FactoryBot.define do
  factory :group do
    name { "テストグループ" }
    association :project
  end
end

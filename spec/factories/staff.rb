FactoryBot.define do
  factory :staff do
    name { "テストスタッフ" }
    position { "OP" }
    comment { "テストコメント" }
    association :project
  end
end

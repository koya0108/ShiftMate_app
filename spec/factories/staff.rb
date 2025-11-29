FactoryBot.define do
  factory :staff do
    name { "テストスタッフ" }
    position { "OP" }
    comment { "テストコメント" }
    association :project

    trait :with_ng_break_room do
      after(:create) do |staff|
        break_room = create(:break_room, project: staff.project)
        create(:staff_break_room_ng, staff: staff, break_room: break_room)
      end
    end
  end
end

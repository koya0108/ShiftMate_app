FactoryBot.define do
  factory :shift_detail do
    rest_start_time { Time.current.change(hour: 12) }
    rest_end_time { Time.current.change(hour: 13) }
    comment { "テストコメント" }

    association :staff
    association :shift
    association :break_room
  end
end

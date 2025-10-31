FactoryBot.define do
  factory :user do
    sequence(:employee_code) { |n| "E#{n.to_s.rjust(3, '0')}" }
    email { Faker::Internet.email }
    password { "password123" }
    confirmed_at { Time.current }
  end
end

FactoryBot.define do
  factory :shift do
    shift_date { Date.today }
    shift_category { :day }
    status { :draft }

    association :user
    association :project
  end
end

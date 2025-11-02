FactoryBot.define do
  factory :shift do
    shift_date { Date.today }
    shift_category { :night }
    status { :draft }

    association :user
    association :project
  end
end

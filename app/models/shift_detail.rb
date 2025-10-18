class ShiftDetail < ApplicationRecord
  belongs_to :staff
  belongs_to :shift
  belongs_to :group, optional: true
  belongs_to :break_room, optional: true
  validates :rest_start_time, :rest_end_time, presence: true
  validates :comment, length: { maximum: 15 }

  def rest_start_time_jst
    rest_start_time&.in_time_zone("Tokyo")
  end

  def rest_end_time_jst
    rest_end_time&.in_time_zone("Tokyo")
  end
end

class BreakRoom < ApplicationRecord
  belongs_to :project
  has_many :shift_details, dependent: :destroy
  has_many :staff_break_room_ngs, dependent: :destroy

  validates :name, presence: true
end

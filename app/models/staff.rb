class Staff < ApplicationRecord
  belongs_to :project
  has_many :shift_details, dependent: :destroy
  has_many :staff_break_room_ngs, dependent: :destroy
  has_many :ng_break_rooms, through: :staff_break_room_ngs, source: :break_room

  validates :name, presence: true
  validates :position, presence: true
  validates :comment, length: { maximum: 15 }

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "position" ]
  end
end

class Staff < ApplicationRecord
  belongs_to :project
  has_many :shift_details, dependent: :destroy

  validates :name, presence: true
  validates :position, presence: true
  validates :comment, length: { maximum: 15 }

  def self.ransackable_attributes(auth_object = nil)
    [ "name", "position" ]
  end
end

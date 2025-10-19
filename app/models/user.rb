class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         authentication_keys: [ :employee_code ]

  has_many :projects, dependent: :destroy

  validates :employee_code, presence: true, uniqueness: true
end

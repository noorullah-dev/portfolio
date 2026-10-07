# A geographic area inside a shop. Recovery officers are assigned to locations
# and may only see/handle customers, sales and instalments in those locations.
class Location < ApplicationRecord
  include TenantScoped
  location_scoped!(column: :id)

  belongs_to :business

  has_many :customers, dependent: :nullify
  has_many :user_locations, dependent: :destroy
  has_many :users, through: :user_locations

  validates :name, presence: true, uniqueness: { scope: :business_id, case_sensitive: false }
  validates :status, inclusion: { in: %w[active inactive] }

  scope :active, -> { where(status: "active") }
  scope :ordered, -> { order(:name) }

  def to_s = name

  def full_name
    [name, city.presence].compact.join(" - ")
  end

  def customer_count
    customers.count
  end

  def officers
    users.where(role: "recovery_officer")
  end
end
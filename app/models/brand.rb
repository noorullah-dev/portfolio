class Brand < ApplicationRecord
  include TenantScoped
  shop_wide_reference_data!

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  has_many :products
  has_many :stock_units, through: :products

  # A brand belongs to a shop, so two shops may both stock Bosch.
  validates :name, presence: true, uniqueness: { scope: :business_id, case_sensitive: false }

  scope :active, -> { where(status: 'active').order(:name) }
  scope :inactive, -> { where(status: 'inactive') }
end

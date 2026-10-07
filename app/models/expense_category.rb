class ExpenseCategory < ApplicationRecord
  include TenantScoped
  shop_wide_reference_data!

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  has_many :expenses

  validates :name, presence: true

  scope :active, -> { where(status: 'active').order(:name) }
end

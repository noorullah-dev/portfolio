class Category < ApplicationRecord
  include TenantScoped
  shop_wide_reference_data!

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  has_many :products, dependent: :restrict_with_error

  validates :name, presence: true
  validates :category_type, inclusion: { in: %w[vehicle electronics general] }

  scope :active, -> { where(status: 'active').order(:name) }
end

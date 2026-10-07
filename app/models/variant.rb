class Variant < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :product

  has_many :stock_units

  validates :value, presence: true

  scope :active, -> { where(status: 'active').includes(product: :brand).order(:value) }

  def display_name
    [product&.display_name, value].compact.join(" / ")
  end

  def profit
    sale_price.to_d - purchase_price.to_d
  end
end

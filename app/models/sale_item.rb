class SaleItem < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :sale
  belongs_to :product, optional: true
  belongs_to :variant, optional: true
  belongs_to :stock_unit, optional: true

  before_validation :compute_total

  def compute_total
    self.total = (qty.to_d * unit_price.to_d) - discount.to_d
  end
end

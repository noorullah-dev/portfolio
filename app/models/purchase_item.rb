class PurchaseItem < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :purchase
  belongs_to :product, optional: true
  belongs_to :variant, optional: true

  before_validation :compute_total
  validate :stock_unit_numbers_available

  def compute_total
    self.total = qty.to_d * unit_price.to_d
  end

  private

  # Stock units are created in an after_create hook, so a clash there would fail
  # the purchase save with no message at all. Catch it while the form is in hand.
  def stock_unit_numbers_available
    return unless create_stock_unit?

    # Engine and chassis numbers identify a vehicle across the whole platform,
    # so this clash check is deliberately not limited to the current shop.
    if engine_no.present? && StockUnit.unscoped.where("LOWER(engine_no) = ?", engine_no.to_s.downcase).exists?
      errors.add(:engine_no, "is already used by another vehicle")
    end

    return unless chassis_no.present?
    return unless StockUnit.unscoped.where("LOWER(chassis_no) = ?", chassis_no.to_s.downcase).exists?

    errors.add(:chassis_no, "is already used by another vehicle")
  end
end
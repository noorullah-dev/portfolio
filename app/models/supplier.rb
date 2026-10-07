class Supplier < ApplicationRecord
  include TenantScoped
  shop_wide_reference_data!

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  has_many :purchases
  has_many :purchase_payments

  validates :name, presence: true

  scope :active, -> { where(status: 'active').order(:name) }

  def total_purchases
    purchases.where.not(status: "cancelled").sum(:total_amount)
  end

  def total_paid
    purchases.where.not(status: "cancelled").sum(:paid_amount)
  end

  def balance
    total_purchases - total_paid
  end
end

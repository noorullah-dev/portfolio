class PaymentMode < ApplicationRecord
  include TenantScoped
  shop_wide_reference_data!

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  validates :name, presence: true

  scope :active, -> { where(status: 'active').order(:sort_order, :name) }
  scope :cash, -> { where(is_cash: true) }

  scope :cash_first, -> { order(Arel.sql("is_cash DESC"), :sort_order, :name) }

  def to_s
    name
  end
end

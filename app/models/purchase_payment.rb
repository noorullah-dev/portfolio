class PurchasePayment < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :purchase
  belongs_to :payment_mode, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  scope :recent, -> { order(payment_date: :desc, id: :desc) }
  scope :between, ->(from, to) { where(payment_date: from..to) }
end

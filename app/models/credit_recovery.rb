class CreditRecovery < ApplicationRecord
  include TenantScoped
  location_scoped!(through: :customer_id, via: "Customer")

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :sale
  belongs_to :customer
  belongs_to :payment_mode, optional: true
  belongs_to :created_by, class_name: "User", optional: true
end

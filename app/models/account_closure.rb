class AccountClosure < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :customer
  belongs_to :sale, optional: true
  belongs_to :created_by, class_name: "User", optional: true
end

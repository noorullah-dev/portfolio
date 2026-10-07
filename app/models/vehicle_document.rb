class VehicleDocument < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :sale
  belongs_to :customer, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  DOCUMENT_TYPES = %w[
    registration_card letter warranty_book insurance_challan
    engine_chassis_copy bill_of_sale other
  ].freeze

  validates :document_type, presence: { message: "is required" }
  validates :document_type, inclusion: { in: DOCUMENT_TYPES }, allow_blank: true

  scope :outstanding, -> { where(received: false) }
  scope :ordered, -> { order(expected_date: :asc, id: :asc) }
end

class InstallmentReminder < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  CHANNELS = %w[sms call whatsapp email letter].freeze

  belongs_to :installment_plan
  belongs_to :sale, optional: true
  belongs_to :customer, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :channel, inclusion: { in: CHANNELS }
end

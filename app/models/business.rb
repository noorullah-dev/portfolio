class Business < ApplicationRecord
  CASH_ACCOUNT_CODE = "1000".freeze
  BANK_ACCOUNT_CODE = "1010".freeze
  RECEIVABLE_ACCOUNT_CODE = "1100".freeze
  INVENTORY_ACCOUNT_CODE = "1200".freeze
  PAYABLE_ACCOUNT_CODE = "2100".freeze
  SALES_ACCOUNT_CODE = "3100".freeze
  COST_OF_SALES_ACCOUNT_CODE = "4100".freeze
  DEFAULT_EXPENSE_CODE = "5100".freeze

  # Captured Business Settings stored the type as a dropdown of 1/2/3.
  BUSINESS_TYPES = {
    "1" => "Motorbike Only",
    "2" => "Electronics Only",
    "3" => "Combined (Motorbike + Electronics)"
  }.freeze

  belongs_to :provisioned_by, class_name: "User", optional: true

  has_many :users, dependent: :nullify
  has_many :branches, dependent: :restrict_with_error
  has_many :locations, dependent: :restrict_with_error
  has_many :customers, dependent: :restrict_with_error
  has_many :sales, dependent: :restrict_with_error
  has_many :audit_logs, dependent: :nullify

  validates :name, presence: true

  class << self
    def current
      first || create_default!
    end

    def create_default!
      create!(name: ENV.fetch("BUSINESS_NAME", "Tamoor Autos"), business_type: "3", currency: "Rs.")
    end

    # Resolves a system account for the shop in context. Accounts are duplicated
    # per business, so a lookup must never fall back to another shop's chart.
    def account(code)
      scope = if Current.cross_tenant?
        ChartOfAccount.all
      else
        ChartOfAccount.where(business_id: Current.business_id)
      end
      scope.find_by!(code: code)
    end
  end

  def business_type_label
    BUSINESS_TYPES[business_type.to_s].presence || business_type.presence
  end

  # The captured field was "Currency Symbol" (e.g. Rs.), not an ISO code.
  def currency_symbol
    currency.presence || "Rs."
  end

  def logo_path
    logo_filename.blank? ? "/icon.png" : "/uploads/#{logo_filename}"
  end
end
class ChartOfAccount < ApplicationRecord
  include TenantScoped
  shop_wide_reference_data!

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  TYPES = %w[asset liability equity income expense].freeze

  belongs_to :parent, class_name: "ChartOfAccount", optional: true
  has_many :children, class_name: "ChartOfAccount", foreign_key: :parent_id,
                      inverse_of: :parent, dependent: :nullify
  has_many :ledger_entries, foreign_key: :account_id, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: { scope: :business_id, case_sensitive: false }
  validates :account_type, inclusion: { in: TYPES }

  scope :of_type, ->(type) { where(account_type: type).order(:code) }
  scope :cash_accounts, -> { where(is_cash_account: true).order(:code) }
  scope :active, -> { where(status: "active").order(:code) }

  def self.trees_for(type)
    of_type(type).includes(:parent).map { |account| [account, account.children.order(:code).to_a] }
  end

  def debit_balance
    ledger_entries.sum(:debit) - ledger_entries.sum(:credit)
  end

  def credit_balance
    ledger_entries.sum(:credit) - ledger_entries.sum(:debit)
  end

  def balance
    case account_type
    when "asset", "expense" then debit_balance
    else -credit_balance
    end
  end

  def to_s
    "#{code} - #{name}"
  end
end
class Voucher < ApplicationRecord
  include TenantScoped

  include DocumentNumbering

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  KINDS = %w[receipt payment].freeze

  belongs_to :payment_mode, optional: true
  belongs_to :account, class_name: "ChartOfAccount", foreign_key: :account_id, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :ledger_entries, as: :source, dependent: :nullify

  validates :kind, inclusion: { in: KINDS }
  validates :voucher_date, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :party_type, inclusion: { in: %w[Customer Supplier Other] }, allow_nil: true

  scope :recent, -> { order(voucher_date: :desc, id: :desc) }
  scope :receipts, -> { where(kind: "receipt") }
  scope :payments, -> { where(kind: "payment") }
  scope :between, ->(from, to) { where(voucher_date: from..to) }

  before_validation :assign_defaults
  after_create :post_to_ledger!
  after_create :record_cash!

  def document_number_kind
    kind.to_s == "payment" ? :payment : :receipt
  end

  def receipt?
    kind == "receipt"
  end

  def payment?
    kind == "payment"
  end

  def to_s
    voucher_no
  end

  private

  def assign_defaults
    self.account ||= receipt? ? Business.account(Business::RECEIVABLE_ACCOUNT_CODE)
                               : Business.account(Business::PAYABLE_ACCOUNT_CODE)
  end

  def post_to_ledger!
    cash = CashBook.account_for(payment_mode)

    lines =
      if receipt?
        [
          { account: cash, debit: amount, particulars: "#{voucher_no} #{party_name}",
            party_type: party_type, party_id: party_id },
          { account: account, credit: amount, particulars: "#{voucher_no} #{party_name}",
            party_type: party_type, party_id: party_id }
        ]
      else
        [
          { account: account, debit: amount, particulars: "#{voucher_no} #{party_name}",
            party_type: party_type, party_id: party_id },
          { account: cash, credit: amount, particulars: "#{voucher_no} #{party_name}" }
        ]
      end

    LedgerPosting.call(
      date: voucher_date,
      source_type: "Voucher",
      source_id: id,
      source_no: voucher_no,
      created_by: created_by,
      lines: lines
    )
  end

  def record_cash!
    CashBook.record(
      direction: receipt? ? "in" : "out",
      amount: amount,
      date: voucher_date,
      payment_mode: payment_mode,
      particulars: "#{voucher_no} #{party_name}",
      source_type: "Voucher",
      source_id: id,
      source_no: voucher_no,
      created_by: created_by
    )
  end
end
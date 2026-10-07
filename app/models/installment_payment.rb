class InstallmentPayment < ApplicationRecord
  include TenantScoped
  location_scoped!(through: :customer_id, via: "Customer")

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :installment_plan, optional: true
  belongs_to :sale
  belongs_to :customer
  belongs_to :payment_mode, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :payment_date, presence: true

  before_validation :inherit_customer_from_sale

  scope :recent, -> { order(payment_date: :desc, id: :desc) }
  scope :between, ->(from, to) { where(payment_date: from..to) }

  after_create :allocate_to_plans!
  after_create :post_to_ledger!

  def self.register!(sale:, amount:, payment_date: Date.current, payment_mode: nil, reference: nil,
                      remarks: nil, created_by: nil, customer: nil)
    amount = amount.to_d
    raise ArgumentError, "Payment amount must be positive" unless amount.positive?

    transaction do
      create!(
        sale: sale,
        customer: customer || sale.customer,
        amount: amount,
        payment_date: payment_date,
        payment_mode: payment_mode,
        reference: reference,
        remarks: remarks,
        created_by: created_by
      )
    end
  end

  def allocated_amount
    @allocated_amount.to_d
  end

  def remaining_after_allocation
    amount.to_d - allocated_amount
  end

  def advance?
    advance_amount.to_d.positive?
  end

  # what is still owed on the sale once this payment has been allocated
  def short_amount
    sale ? sale.balance.to_d : 0.to_d
  end

  private

  def inherit_customer_from_sale
    self.customer_id ||= sale&.customer_id
  end

  def allocate_to_plans!
    leftover = amount.to_d

    sale.installment_plans.unpaid.chronological.each do |plan|
      break if leftover <= 0

      due = plan.remaining
      next if due <= 0

      applied = [due, leftover].min
      plan.apply_payment!(applied)
      @allocated_amount = @allocated_amount.to_d + applied
      leftover -= applied
    end

    @allocated_amount = @allocated_amount.to_d
    self.is_short = sale.installment_plans.unpaid.chronological.first&.remaining.to_d.positive?
    self.advance_amount = leftover.round(2)
    update_columns(is_short: is_short, advance_amount: advance_amount)
    customer.refresh_defaulter_status!
  end

  def post_to_ledger!
    receivable = Business.account(Business::RECEIVABLE_ACCOUNT_CODE)
    cash = CashBook.account_for(payment_mode)

    LedgerPosting.call(
      date: payment_date,
      source_type: "InstallmentPayment",
      source_id: id,
      source_no: sale.sale_no,
      created_by: created_by,
      lines: [
        { account: cash, debit: amount, particulars: "Installment received #{sale.sale_no}",
          party_type: "Customer", party_id: customer_id },
        { account: receivable, credit: amount, particulars: "Installment received #{sale.sale_no}",
          party_type: "Customer", party_id: customer_id }
      ]
    )

    CashBook.record(
      direction: "in",
      amount: amount,
      date: payment_date,
      payment_mode: payment_mode,
      particulars: "Installment against #{sale.sale_no} - #{customer.name}",
      source_type: "InstallmentPayment",
      source_id: id,
      source_no: sale.sale_no,
      created_by: created_by
    )
  end
end
class Sale < ApplicationRecord
  include TenantScoped
  location_scoped!(through: :customer_id, via: "Customer")

  include DocumentNumbering

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  SALE_TYPES = %w[cash credit].freeze
  STATUSES = %w[completed cancelled returned].freeze

  belongs_to :customer
  belongs_to :product, optional: true
  belongs_to :variant, optional: true
  belongs_to :stock_unit, optional: true
  belongs_to :payment_mode, optional: true
  belongs_to :agent, optional: true
  belongs_to :salesman, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :items, class_name: "SaleItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true
  has_many :installment_plans, dependent: :destroy
  has_many :installment_payments, dependent: :restrict_with_error
  has_many :installment_reminders, dependent: :nullify
  has_many :post_dated_cheques, dependent: :nullify
  has_many :credit_recoveries, dependent: :destroy
  has_one :registration_tracking, dependent: :destroy
  has_many :vehicle_documents, dependent: :destroy
  has_many :account_transfers, dependent: :nullify
  has_many :account_closures, dependent: :nullify
  has_many :agent_commissions, dependent: :destroy
  has_many :quotations, dependent: :nullify, foreign_key: :converted_sale_id
  has_many :ledger_entries, as: :source, dependent: :nullify

  validates :sale_date, presence: true
  validates :sale_type, inclusion: { in: SALE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :total_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :down_payment, numericality: { greater_than_or_equal_to: 0 }
  validate :down_payment_within_total

  scope :recent, -> { order(sale_date: :desc, id: :desc) }
  scope :completed, -> { where(status: "completed") }
  scope :credit, -> { where(sale_type: "credit") }
  scope :cash, -> { where(sale_type: "cash") }
  scope :between, ->(from, to) { where(sale_date: from..to) }
  scope :active_sales, -> { where.not(status: %w[cancelled returned]) }
  scope :active_sale_ids, -> { active_sales.select(:id) }

  scope :search, lambda { |term|
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    joins(:customer)
      .where("sales.sale_no ILIKE :q OR sales.reg_no ILIKE :q OR customers.name ILIKE :q OR customers.account_no ILIKE :q",
             q: pattern)
  }

  before_validation :apply_financials
  after_create :schedule_installments!
  after_create :mark_stock_unit_sold!
  after_create :create_agent_commission!
  after_create :post_finance_entries!

  def document_number_kind
    :sale
  end

  def display_name
    [sale_no, customer&.name].compact.join(" - ")
  end

  def to_s
    sale_no
  end

  def credit_sale?
    sale_type == "credit"
  end

  def cancelled?
    status == "cancelled"
  end

  def vehicle_label
    stock_unit&.label.presence ||
      [product&.display_name, variant&.value].compact.join(" ").presence ||
      items.first&.description.to_s
  end

  def cost_amount
    self[:cost_amount].presence || stock_unit&.cost_price.to_d || 0
  end

  def gross_amount
    total_amount.to_d - discount.to_d
  end

  def monthly_amount
    return 0.to_d unless months.to_i.positive?

    InstallmentPlanner.monthly_installment(amount: financed_amount, months: months)
  end

  def installment_summary
    plans = installment_plans.order(:installment_no)
    {
      total: plans.sum(&:amount),
      paid: plans.sum(&:paid_amount),
      remaining: plans.sum { |plan| plan.remaining },
      overdue: plans.select(&:overdue?).sum { |plan| plan.remaining },
      next_due: plans.reject(&:paid?).first&.due_date
    }
  end

  def balance
    installment_plans.sum { |plan| plan.remaining }
  end

  def paid_amount
    installment_payments.sum(:amount)
  end

  # Instalments already past their due date and still unpaid.
  def overdue_amount
    installment_plans.reject { |plan| plan.paid? || plan.due_date.nil? || plan.due_date >= Date.current }
                      .sum { |plan| plan.remaining.to_d }
  end

  def closed?
    credit_sale? && installment_plans.any? && balance <= 0
  end

  def cancel!(reason = nil)
    transaction do
      installment_payments.destroy_all if installment_payments.exists?
      stock_unit&.release!
      update!(status: "cancelled", notes: [notes, "Cancelled: #{reason}"].compact.join(" | "))
    end
  end

  def first_due_date
    return sale_date if months.to_i <= 0

    day = business&.default_installment_day.to_i || Current.business&.default_installment_day.to_i || 1
    due = sale_date + 1.month
    due = due.change(day: day) if due.day != day && day.between?(1, 28)
    due
  end

  private

  def down_payment_within_total
    return if down_payment.to_d <= 0
    return if gross_amount > 0 && down_payment.to_d <= gross_amount

    errors.add(:down_payment, "cannot be more than the net sale amount (#{gross_amount})")
  end

  def apply_financials
    total = gross_amount
    down = down_payment.to_d
    months_count = months.to_i

    if months_count.positive?
      financed = total - down
      financed = 0 if financed.negative?
      self.financed_amount = financed
      self.monthly_amount = InstallmentPlanner.monthly_installment(amount: financed, months: months_count)
    else
      self.financed_amount = credit_sale? ? total : 0
      self.monthly_amount = 0
    end

    self.cost_amount = [cost_amount.to_d, total].min
    self.profit_amount = total - self.cost_amount
  end

  def schedule_installments!
    return unless credit_sale? && months.to_i.positive?

    rows = InstallmentPlanner.call(amount: financed_amount, months: months, first_due_date: first_due_date)
    rows.each do |row|
      installment_plans.create!(
        installment_no: row[:installment_no],
        due_date: row[:due_date],
        amount: row[:amount]
      )
    end
  end

  def mark_stock_unit_sold!
    stock_unit&.sell!(self)
  end

  def create_agent_commission!
    return if agent.nil?
    return if agent.commission_amount.to_d <= 0

    earned = if agent.commission_type == "fixed"
      agent.commission_amount.to_d
    else
      (gross_amount * agent.commission_amount.to_d / 100).round(2)
    end

    AgentCommission.create!(
      agent: agent,
      sale: self,
      customer: customer,
      sale_date: sale_date,
      sale_no: sale_no,
      basis_amount: gross_amount,
      commission_type: agent.commission_type,
      commission_value: agent.commission_amount,
      earned_amount: earned
    )
  end

  def post_finance_entries!
    receivable = Business.account(Business::RECEIVABLE_ACCOUNT_CODE)
    sales_account = Business.account(Business::SALES_ACCOUNT_CODE)
    inventory = Business.account(Business::INVENTORY_ACCOUNT_CODE)
    cost_account = Business.account(Business::COST_OF_SALES_ACCOUNT_CODE)
    cash = CashBook.account_for(payment_mode)

    lines = []
    if credit_sale?
      if down_payment.to_d.positive?
        lines << { account: cash, debit: down_payment, particulars: "Down payment for #{sale_no}" }
        lines << { account: receivable, debit: financed_amount,
                   particulars: "Financed amount for #{sale_no}",
                   party_type: "Customer", party_id: customer_id }
      else
        lines << { account: receivable, debit: financed_amount,
                   particulars: "Financed amount for #{sale_no}",
                   party_type: "Customer", party_id: customer_id }
      end
      lines << { account: sales_account, credit: gross_amount, particulars: "Vehicle sale #{sale_no}" }
    else
      lines << { account: cash, debit: gross_amount, particulars: "Cash sale #{sale_no}" }
      lines << { account: sales_account, credit: gross_amount, particulars: "Vehicle sale #{sale_no}" }
    end

    if cost_amount.to_d.positive?
      lines << { account: cost_account, debit: cost_amount, particulars: "Cost of vehicle #{sale_no}" }
      lines << { account: inventory, credit: cost_amount, particulars: "Stock dispatched #{sale_no}" }
    end

    LedgerPosting.call(
      date: sale_date,
      source_type: "Sale",
      source_id: id,
      source_no: sale_no,
      created_by: created_by,
      lines: lines
    )

    if credit_sale? && down_payment.to_d.positive?
      CashBook.record(
        direction: "in",
        amount: down_payment,
        date: sale_date,
        payment_mode: payment_mode,
        particulars: "Down payment for #{sale_no} - #{customer.name}",
        source_type: "Sale",
        source_id: id,
        source_no: sale_no,
        created_by: created_by
      )
    end
  end
end
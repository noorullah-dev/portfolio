class AdvanceBooking < ApplicationRecord
  include TenantScoped
  location_scoped!(through: :customer_id, via: "Customer")

  include DocumentNumbering

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  STATUSES = %w[confirmed delivered cancelled].freeze

  belongs_to :customer, optional: true
  belongs_to :product, optional: true
  belongs_to :variant, optional: true
  belongs_to :stock_unit, optional: true
  belongs_to :agent, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :payments, class_name: "AdvanceBookingPayment", dependent: :destroy
  accepts_nested_attributes_for :payments, allow_destroy: true
  has_many :plans, class_name: "AdvanceBookingPlan", dependent: :destroy

  validates :booking_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :booking_no, presence: true, uniqueness: true

  scope :recent, -> { order(booking_date: :desc, id: :desc) }
  scope :active_bookings, -> { where(status: "confirmed") }

  before_validation :apply_financials
  after_create :build_plans!

  def document_number_kind
    :booking
  end

  def to_s
    booking_no
  end

  def vehicle_label
    [product&.display_name, variant&.value, customer&.name].compact_blank.join(" ")
  end

  def paid_amount
    payments.sum(:amount)
  end

  def balance
    total_amount.to_d - paid_amount
  end

  def record_payment!(amount:, payment_date: Date.current, payment_mode: nil, remarks: nil, created_by: nil)
    amount = amount.to_d
    raise ArgumentError, "Payment amount must be positive" unless amount.positive?

    transaction do
      payment = payments.create!(
        payment_date: payment_date,
        amount: amount,
        payment_mode: payment_mode,
        remarks: remarks,
        created_by: created_by
      )

      CashBook.record(
        direction: "in",
        amount: amount,
        date: payment_date,
        payment_mode: payment_mode,
        particulars: "Advance booking #{booking_no} - #{customer&.name}",
        source_type: "AdvanceBookingPayment",
        source_id: payment.id,
        source_no: booking_no,
        created_by: created_by
      )

      payment
    end
  end

  private

  def apply_financials
    total = total_amount.to_d
    self.balance_amount = total - advance_amount.to_d
    if months.to_i.positive?
      self.monthly_amount = InstallmentPlanner.monthly_installment(amount: balance_amount, months: months)
    else
      self.monthly_amount = 0
    end
  end

  def build_plans!
    return unless months.to_i.positive?

    rows = InstallmentPlanner.call(amount: balance_amount, months: months, first_due_date: booking_date + 1.month)
    rows.each do |row|
      plans.create!(installment_no: row[:installment_no], due_date: row[:due_date], amount: row[:amount])
    end
  end
end
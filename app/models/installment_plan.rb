class InstallmentPlan < ApplicationRecord
  include TenantScoped
  location_scoped!(through: :sale_id, via: "Sale")

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :sale

  has_many :reminders, class_name: "InstallmentReminder", dependent: :destroy
  has_many :payments, class_name: "InstallmentPayment", dependent: :nullify

  validates :installment_no, presence: true, uniqueness: { scope: :sale_id }
  validates :due_date, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  scope :chronological, -> { order(:installment_no) }
  scope :paid, -> { where(status: "paid") }
  scope :unpaid, -> { where.not(status: "paid") }
  scope :due_before, ->(date) { where(due_date: ...date) }
  scope :due_on, ->(date) { where(due_date: date) }
  scope :due_between, ->(from, to) { where(due_date: from..to) }

  after_initialize :set_defaults

  def paid?
    status == "paid"
  end

  def remaining
    amount.to_d - paid_amount.to_d
  end

  def settled?
    remaining <= 0
  end

  def overdue?
    !paid? && due_date.present? && due_date < Date.current
  end

  def due_today?
    !paid? && due_date == Date.current
  end

  def days_overdue
    return 0 unless overdue?

    (Date.current - due_date).to_i
  end

  def days_until_due
    return 0 unless due_date.present?

    (due_date - Date.current).to_i
  end

  def apply_payment!(value)
    value = value.to_d.round(2)
    self.paid_amount = paid_amount.to_d + value
    self.late_fee = late_fee.to_d
    self.short_amount = remaining.negative? ? remaining.abs : 0
    self.paid_date = Date.current if remaining <= 0
    self.status = if remaining <= 0
      "paid"
    elsif value.positive?
      "partial"
    else
      "pending"
    end
    save!
    self
  end

  def compute_late_fee!(rule = nil)
    return if paid?

    rule ||= sale&.late_fee_type
    self.late_fee = case rule
    when "percent"
      (remaining * 0.01).round(2)
    when "fixed"
      sale&.payment_mode.present? ? 0 : 0
    else
      late_fee.to_d
    end
    save!
  end

  private

  def set_defaults
    self.status ||= "pending"
    self.paid_amount ||= 0
    self.late_fee ||= 0
    self.short_amount ||= 0
  end
end
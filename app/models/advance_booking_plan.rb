class AdvanceBookingPlan < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :advance_booking

  scope :chronological, -> { order(:installment_no) }
  scope :paid, -> { where(status: "paid") }
  scope :unpaid, -> { where.not(status: "paid") }

  validates :installment_no, presence: true, uniqueness: { scope: :advance_booking_id }
  validates :due_date, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def balance
    amount.to_d - paid_amount.to_d
  end
  alias remaining balance

  def paid?
    status == "paid"
  end

  def settled?
    remaining <= 0
  end

  def overdue?
    status != "paid" && due_date.present? && due_date < Date.current
  end

  def overdue?
    status != "paid" && due_date < Date.current
  end
end

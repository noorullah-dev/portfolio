class AgentCommission < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :agent
  belongs_to :sale
  belongs_to :customer, optional: true

  has_many :payments, class_name: "AgentCommissionPayment", dependent: :destroy

  before_validation :derive_amount

  validates :earned_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :sale_id, uniqueness: { message: "already has a commission recorded" }

  def balance
    earned_amount.to_d - paid_amount.to_d
  end

  def paid?
    balance <= 0
  end

  private

  def derive_amount
    self.sale_no ||= sale&.sale_no
    self.customer_id ||= sale&.customer_id
    self.sale_date ||= sale&.sale_date

    basis = basis_amount.to_d
    basis = sale&.total_amount.to_d if basis.zero?
    self.basis_amount = basis

    self.earned_amount = commission_type == "fixed" ? commission_value.to_d : (basis * commission_value.to_d / 100).round(2)

    self.status = if paid_amount.to_d.positive?
      balance <= 0 ? "paid" : "partial"
    else
      "pending"
    end
  end
end

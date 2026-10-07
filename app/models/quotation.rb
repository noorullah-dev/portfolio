class Quotation < ApplicationRecord
  include TenantScoped

  include DocumentNumbering

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  STATUSES = %w[draft sent accepted rejected converted].freeze

  belongs_to :customer, optional: true
  belongs_to :product, optional: true
  belongs_to :variant, optional: true
  belongs_to :converted_sale, class_name: "Sale", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :plans, class_name: "QuotationPlan", dependent: :destroy

  validates :quotation_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :quotation_no, presence: true, uniqueness: true

  scope :recent, -> { order(quotation_date: :desc, id: :desc) }
  scope :open_quotes, -> { where(status: %w[draft sent]) }

  before_validation :compute_monthly
  after_create :build_plans!

  def document_number_kind
    :quotation
  end

  def to_s
    quotation_no
  end

  def vehicle_label
    [product&.display_name, variant&.value].compact_blank.join(" ")
  end

  def open_quote?
    status.in?(%w[draft sent])
  end

  def financed_amount
    sale_price.to_d - down_payment.to_d
  end

  def accept!(sale: nil)
    update!(status: "converted", converted_sale_id: sale&.id)
  end

  private

  def compute_monthly
    self.monthly_amount = InstallmentPlanner.monthly_installment(amount: financed_amount, months: months)
  end

  def build_plans!
    return unless months.to_i.positive?

    rows = InstallmentPlanner.call(amount: financed_amount, months: months, first_due_date: quotation_date + 1.month)
    rows.each { |row| plans.create!(row) }
  end
end
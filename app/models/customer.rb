class Customer < ApplicationRecord
  include TenantScoped
  shop_wide_reference_data!
  location_scoped!

  include DocumentNumbering

  # Customers belong to a business and, optionally, to one location. They are
  # deliberately not branch scoped - a customer is served by every branch.
  belongs_to :business, optional: true
  belongs_to :location, optional: true

  belongs_to :agent, optional: true
  belongs_to :salesman, class_name: "User", optional: true

  has_many :sales, dependent: :restrict_with_error
  has_many :installment_payments, dependent: :restrict_with_error
  has_many :installment_reminders, dependent: :nullify
  has_many :post_dated_cheques, dependent: :nullify
  has_many :credit_recoveries, dependent: :nullify
  has_many :advance_bookings, dependent: :nullify
  has_many :registration_trackings, dependent: :nullify
  has_many :vehicle_documents, dependent: :nullify
  has_many :account_closures, dependent: :nullify
  has_many :sent_transfers, class_name: "AccountTransfer", dependent: :nullify,
                            foreign_key: :from_customer_id
  has_many :received_transfers, class_name: "AccountTransfer", dependent: :nullify,
                                 foreign_key: :to_customer_id
  has_many :agent_commissions, dependent: :nullify

  validates :name, presence: true
  validates :account_no, presence: true, uniqueness: { case_sensitive: false }
  validates :phone, format: { with: /\A[0-9+\-\s()]{6,20}\z/, message: "is not a valid number" },
                    allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :customer_type, inclusion: { in: %w[individual company] }

  scope :active, -> { where(status: "active").order(:name) }
  scope :defaulters, -> { where(is_defaulter: true) }
  scope :search, lambda { |term|
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("customers.name ILIKE :q OR customers.account_no ILIKE :q OR customers.phone ILIKE :q OR customers.cnic ILIKE :q",
          q: pattern)
  }

  after_save :refresh_defaulter_flag

  def document_number_kind
    :customer
  end

  def display_name
    [account_no, name].compact.join(" - ")
  end

  def to_s
    name
  end

  def active_sales
    sales.where.not(status: %w[cancelled returned])
  end

  def financed_total
    active_sales.sum(:financed_amount)
  end

  def paid_total
    installment_payments.sum(:amount)
  end

  def balance
    opening_balance.to_d + financed_total - paid_total
  end

  def overdue_amount
    overdue_plans.sum { |plan| plan.remaining }
  end

  # Instalments where the customer paid less than scheduled (short payments).
  def short_plans
    InstallmentPlan.shop.where(sale_id: active_sales.select(:id))
                   .where("short_amount > 0 OR (paid_amount > 0 AND paid_amount < amount)")
  end

  def short_plan_count
    short_plans.count
  end

  def short_pending_total
    short_plans.sum { |plan| plan.short_amount.to_d.positive? ? plan.short_amount.to_d : plan.remaining.to_d }
  end

  def overdue_plans
    InstallmentPlan.shop.where(sale_id: active_sales.select(:id))
                   .where.not(status: "paid")
                   .where(due_date: ...Date.current)
  end

  def upcoming_plans(within_days = 7)
    InstallmentPlan.shop.where(sale_id: active_sales.select(:id))
                   .where.not(status: "paid")
                   .where(due_date: Date.current..(Date.current + within_days.days))
                   .order(:due_date)
  end

  def settled?
    balance <= 0
  end

  # Live check: any installment past its due date still carries a balance.
  def defaulter?
    overdue_plans.exists?
  end

  # Keeps the stored is_defaulter column in step; run after any payment,
  # reminder or plan change, and from the nightly overdue sweep.
  def refresh_defaulter_status!
    update_column(:is_defaulter, defaulter?)
  end

  def photo_path
    photo_filename.present? ? "/uploads/#{photo_filename}" : nil
  end

  private

  def refresh_defaulter_flag
    flag = defaulter?
    update_column(:is_defaulter, flag) if is_defaulter? != flag
  end
end
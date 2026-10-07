class JournalVoucher < ApplicationRecord
  include TenantScoped

  include DocumentNumbering

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  STATUSES = %w[draft posted cancelled].freeze

  belongs_to :posted_by, class_name: "User", optional: true

  has_many :lines, class_name: "JournalVoucherLine", dependent: :destroy
  has_many :ledger_entries, as: :source, dependent: :nullify
  accepts_nested_attributes_for :lines, allow_destroy: true

  validates :voucher_date, presence: true
  validates :status, inclusion: { in: STATUSES }

  before_validation :assign_total
  validate :must_balance

  scope :recent, -> { order(voucher_date: :desc, id: :desc) }
  scope :between, ->(from, to) { where(voucher_date: from..to) }

  def document_number_kind
    :journal
  end

  def to_s
    voucher_no
  end

  def total_debit
    lines.sum(:debit)
  end

  def total_credit
    lines.sum(:credit)
  end

  def balanced?
    lines.any? && (total_debit - total_credit).abs < 0.01
  end

  def posted?
    status == "posted"
  end

  def post!(user: nil)
    errors.add(:base, "Debit and credit totals do not match") unless balanced?
    raise ActiveRecord::RecordInvalid, self if errors.any?

    transaction do
      update!(status: "posted", posted_by: user, posted_at: Time.current)

      LedgerPosting.call(
        date: voucher_date,
        source_type: "JournalVoucher",
        source_id: id,
        source_no: voucher_no,
        created_by: user,
        lines: lines.map do |line|
          { account: line.account,
            debit: line.debit,
            credit: line.credit,
            particulars: line.remarks.presence || description.presence || voucher_no }
        end
      )
    end

    self
  end

  private

  def assign_total
    self.total_amount = total_debit
  end

  def must_balance
    return if lines.empty?
    return if balanced?

    errors.add(:base, "Debit (#{total_debit}) and credit (#{total_credit}) totals do not match")
  end
end
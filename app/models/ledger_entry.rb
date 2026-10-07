class LedgerEntry < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :account, class_name: "ChartOfAccount", foreign_key: :account_id, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :entry_date, presence: true
  validate :single_sided

  scope :chronological, -> { order(entry_date: :asc, id: :asc) }
  scope :recent, -> { order(entry_date: :desc, id: :desc) }
  scope :between, ->(from, to) { where(entry_date: from..to) }
  scope :for_source, ->(type, id) { where(source_type: type, source_id: id) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }
  scope :for_party, ->(type, id) { where(party_type: type, party_id: id) }
  scope :posted, -> { where.not(source_type: [nil, "Opening Balance"]) }

  def debit?
    debit.to_d.positive?
  end

  def credit?
    credit.to_d.positive?
  end

  def amount
    debit.to_d.positive? ? debit.to_d : credit.to_d
  end

  def to_s
    format("%<date>s  %<account>s  D %<debit>s  C %<credit>s",
           date: entry_date, account: account&.code,
           debit: debit.to_d, credit: credit.to_d)
  end

  private

  def single_sided
    if debit.to_d.positive? && credit.to_d.positive?
      errors.add(:base, "A ledger entry is either a debit or a credit, never both")
    elsif debit.to_d <= 0 && credit.to_d <= 0
      errors.add(:base, "A ledger entry needs an amount")
    end
  end
end
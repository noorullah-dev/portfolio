class JournalVoucherLine < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :journal_voucher
  belongs_to :account, class_name: "ChartOfAccount", foreign_key: :account_id

  before_validation :one_sided

  def one_sided
    errors.add(:base, "Enter either a debit or a credit, not both") if debit.to_d.positive? && credit.to_d.positive?
    errors.add(:base, "Amount must be greater than zero") if debit.to_d <= 0 && credit.to_d <= 0
  end
end

class CashBookEntry < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :payment_mode, optional: true
  belongs_to :account, class_name: "ChartOfAccount", foreign_key: :account_id, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  scope :chronological, -> { order(entry_date: :desc, id: :desc) }
  scope :between, ->(from, to) { where(entry_date: from..to) }

  def signed_amount
    cash_in? ? amount.to_d : -amount.to_d
  end

  def source_label
    source_type.to_s.demodulize.presence || "Manual"
  end

  def cash_in?
    direction == "in"
  end

  def cash_out?
    direction == "out"
  end
end

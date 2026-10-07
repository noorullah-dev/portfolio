class Expense < ApplicationRecord
  include TenantScoped

  belongs_to :business, optional: true
  belongs_to :branch, optional: true

  belongs_to :category, class_name: "ExpenseCategory", optional: true
  belongs_to :payment_mode, optional: true
  belongs_to :account, class_name: "ChartOfAccount", foreign_key: :account_id, optional: true
  belongs_to :added_by, class_name: "User", optional: true

  scope :recent, -> { order(expense_date: :desc, id: :desc) }
  scope :between, ->(from, to) { where(expense_date: from..to) }

  after_create :post_to_ledger!
  after_create :record_cash_out!
  before_destroy :reverse_ledger!, prepend: true

  def particulars
    description.presence || category&.name || "Expense"
  end

  private

  def post_to_ledger!
    expense_account = account || Business.account(Business::DEFAULT_EXPENSE_CODE)
    cash = CashBook.account_for(payment_mode)

    LedgerPosting.call(
      date: expense_date,
      source_type: "Expense",
      source_id: id,
      created_by: added_by,
      lines: [
        { account: expense_account, debit: amount, particulars: particulars },
        { account: cash, credit: amount, particulars: particulars }
      ]
    )
  end

  def record_cash_out!
    CashBook.record(
      direction: "out",
      amount: amount,
      date: expense_date,
      payment_mode: payment_mode,
      particulars: particulars,
      source_type: "Expense",
      source_id: id,
      created_by: added_by
    )
  end

  # Deletes leave the ledger and cash book untouched, so mirror the entry.
  def reverse_ledger!
    return if destroyed? && !persisted?

    LedgerEntry.shop.for_source("Expense", id).find_each do |entry|
      LedgerEntry.create!(
        entry_date: entry.entry_date,
        account_id: entry.account_id,
        debit: entry.credit,
        credit: entry.debit,
        source_type: "ExpenseReversal",
        source_id: id,
        source_no: entry.source_no,
        particulars: "Reversal of expense ##{id}",
        created_by_id: entry.created_by_id
      )
    end

    CashBookEntry.shop.where(source_type: "Expense", source_id: id).find_each do |entry|
      CashBookEntry.create!(
        entry_date: entry.entry_date,
        direction: entry.direction == "out" ? "in" : "out",
        particulars: "Reversal: #{entry.particulars}",
        source_type: "ExpenseReversal",
        source_id: id,
        amount: entry.amount,
        payment_mode_id: entry.payment_mode_id,
        account_id: entry.account_id,
        created_by_id: entry.created_by_id
      )
    end
  end
end

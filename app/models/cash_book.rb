# Service object that writes a cash-book entry for every money movement.
# It fills the tenant columns from the signed-in context automatically.
class CashBook
  class << self
    def record(direction:, amount:, date: Date.current, payment_mode: nil, particulars: nil,
               source_type: nil, source_id: nil, source_no: nil, created_by: nil)
      amount = amount.to_d
      raise ArgumentError, "Cash book amount must be positive" unless amount.positive?
      raise ArgumentError, "direction must be in or out" unless %w[in out].include?(direction.to_s)

      CashBookEntry.create!(
        business_id: Current.business_id,
        branch_id: Current.branch_id,
        entry_date: date,
        direction: direction.to_s,
        particulars: particulars,
        source_type: source_type,
        source_id: source_id,
        source_no: source_no,
        amount: amount,
        payment_mode: payment_mode,
        account: account_for(payment_mode),
        created_by: created_by
      )
    end

    def account_for(payment_mode = nil)
      account = if payment_mode&.is_cash?
        Business.account(Business::CASH_ACCOUNT_CODE)
      else
        Business.account(Business::BANK_ACCOUNT_CODE)
      end
      account || ChartOfAccount.shop.where(is_cash_account: true).first
    end
  end
end
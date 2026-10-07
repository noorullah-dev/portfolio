# Amount formatting for controllers (flash messages, notice strings) as well as
# views. ApplicationHelper delegates here so views and flash text always agree.
module MoneyFormat
  def money(amount, currency: true)
    ActiveSupport::NumberHelper.number_to_currency(amount.to_d, unit: currency ? "Rs " : "")
  end

  def plain_number(amount)
    # number_with_delimiter is a view-only helper; the module exposes the
    # equivalent number_to_delimited.
    ActiveSupport::NumberHelper.number_to_delimited(amount.to_d.round(2))
  end
end

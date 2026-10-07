# End to end exercise of the money engine. Run against the development
# database; wraps everything in a rollback so it can be re-run safely.
#
#   bin/rails runner script/smoke_finance.rb

def money(value)
  format("%<value>.2f", value: value.to_d)
end

def assert(label, condition, detail = nil)
  status = condition ? "PASS" : "FAIL"
  puts "[#{status}] #{label}#{detail ? " (#{detail})" : ""}"
  raise "smoke test failed: #{label}" unless condition
end

ActiveRecord::Base.transaction do
  # Money always posts against the signed-in shop's chart of accounts, so the
  # harness runs inside that shop's context.
  Current.set_from(User.find_by!(username: "admin"))
  begin
  cash = PaymentMode.shop.find_by!(name: "Cash")
  bank = PaymentMode.shop.find_by!(name: "Bank")
  brand = Brand.shop.find_by!(name: "Toyota")
  category = Category.shop.find_by!(name: "Corolla")
  agent = Agent.shop.find_by!(name: "Bilal Ahmed")
  supplier = Supplier.shop.find_by!(name: "Indus Motors")

  puts "\n== purchase =="
  purchase = Purchase.create!(
    supplier: supplier,
    purchase_date: 20.days.ago.to_date,
    payment_mode: bank,
    discount: 1000,
    items_attributes: [
      { qty: 1, unit_price: 2_000_000,
        engine_no: "ENG-#{rand(100_000..999_999)}", chassis_no: "CHS-#{rand(100_000..999_999)}",
        create_stock_unit: true, description: "Corolla GLi 2022" },
      { qty: 1, unit_price: 2_000_000,
        engine_no: "ENG-#{rand(100_000..999_999)}", chassis_no: "CHS-#{rand(100_000..999_999)}",
        create_stock_unit: true, description: "Corolla XLE 2023" }
    ]
  )
  assert "purchase total nets discount", purchase.total_amount == 3_999_000, money(purchase.total_amount)
  assert "two stock units created", purchase.stock_units.count == 2
  assert "stock unit is available", purchase.stock_units.all?(&:available?)

  purchase.record_payment!(amount: 500_000, payment_mode: bank, created_by: User.find_by(username: "admin"))
  assert "supplier balance tracked", purchase.balance == 3_499_000, money(purchase.balance)

  puts "\n== sale (credit) =="
  unit = purchase.stock_units.order(:id).last
  customer = Customer.create!(name: "Ali Raza", phone: "03001234567", cnic: "35202-1234567-8",
                              customer_type: "individual")
  assert "customer account number assigned", customer.account_no.present?, customer.account_no

  sale = Sale.create!(
    customer: customer,
    sale_date: Date.current,
    sale_type: "credit",
    stock_unit: unit,
    variant: unit.variant,
    product: unit.product,
    total_amount: 2_600_000,
    discount: 100_000,
    down_payment: 600_000,
    months: 12,
    payment_mode: bank,
    agent: agent,
    cost_amount: unit.cost_price,
    created_by: User.find_by(username: "admin"),
    items_attributes: [{ qty: 1, unit_price: 2_600_000, discount: 100_000, stock_unit_id: unit.id }]
  )

  assert "sale number generated", sale.sale_no.match?(/\ASALE-\d{4}-\d{4}\z/), sale.sale_no
  assert "financed amount excludes down payment", sale.financed_amount == 1_900_000, money(sale.financed_amount)
  assert "twelve installments created", sale.installment_plans.count == 12
  assert "schedule sums to financed amount",
         sale.installment_plans.sum(:amount) == sale.financed_amount,
         money(sale.installment_plans.sum(:amount))
  amounts = sale.installment_plans.chronological.pluck(:amount)
  assert "regular installments share one amount", amounts[0..-2].uniq.size == 1, money(sale.monthly_amount)
  assert "remainder lands on the final installment",
         amounts.last == sale.financed_amount - (amounts.first * 11),
         money(amounts.last)
  assert "stock unit marked sold", unit.reload.sold?
  assert "agent commission earned", sale.agent_commissions.first.earned_amount == 50_000,
         money(sale.agent_commissions.first.earned_amount)

  puts "\n== installments and payments =="
  plans = sale.installment_plans.order(:installment_no).to_a
  first, second = plans.first(2)

  payment = InstallmentPayment.register!(
    sale: sale,
    amount: first.amount + 1_000,
    payment_mode: cash,
    created_by: User.find_by(username: "admin")
  )
  assert "first installment closed", first.reload.paid?
  assert "surplus cascades into the next installment", second.reload.paid_amount == 1_000,
         money(payment.amount)
  assert "customer balance is financed minus payment",
         customer.reload.balance == sale.financed_amount - payment.amount,
         money(customer.balance)
  assert "customer not a defaulter while nothing is overdue", customer.defaulter? == false

  oldest_unpaid = sale.installment_plans.unpaid.order(:installment_no).first
  InstallmentPayment.register!(sale: sale, amount: oldest_unpaid.amount / 2, payment_mode: cash)
  assert "partial payment marks the plan partial", oldest_unpaid.reload.status == "partial"
  assert "short payment flagged", InstallmentPayment.last.is_short?

  oldest_unpaid.update_columns(due_date: 40.days.ago.to_date)
  customer.reload
  assert "overdue customer is a defaulter", customer.defaulter?, money(customer.overdue_amount)

  windfall = InstallmentPayment.register!(sale: sale, amount: sale.balance + 500, payment_mode: cash)
  assert "payment beyond the schedule is held as advance", windfall.advance_amount == 500,
         money(windfall.advance_amount)
  assert "schedule fully settled by the windfall", sale.reload.balance.zero?
  customer.reload
  assert "credit balance settles at the advance", customer.balance == -500, money(customer.balance)
  assert "stored defaulter flag cleared once nothing is overdue", customer.reload.is_defaulter? == false

  puts "\n== vouchers and ledger =="
  receipt = Voucher.create!(kind: "receipt", voucher_date: Date.current, party_type: "Customer",
                            party_id: customer.id, party_name: customer.name, amount: 25_000,
                            payment_mode: cash, account: Business.account(Business::RECEIVABLE_ACCOUNT_CODE))
  assert "receipt number generated", receipt.voucher_no.start_with?("RCV-"), receipt.voucher_no

  payment_voucher = Voucher.create!(kind: "payment", voucher_date: Date.current, party_type: "Supplier",
                                    party_id: supplier.id, party_name: supplier.name, amount: 10_000,
                                    payment_mode: bank)
  assert "payment number generated", payment_voucher.voucher_no.start_with?("PAY-"), payment_voucher.voucher_no

  entries = LedgerEntry.for_source("Sale", sale.id)
  debit = entries.sum(:debit)
  credit = entries.sum(:credit)
  assert "sale ledger posting is balanced", (debit - credit).abs < 0.01, "D #{money(debit)} / C #{money(credit)}"

  all_debit = LedgerEntry.sum(:debit)
  all_credit = LedgerEntry.sum(:credit)
  assert "entire ledger balances", (all_debit - all_credit).abs < 0.01,
         "D #{money(all_debit)} / C #{money(all_credit)}"

  assert "cash book recorded entries", CashBookEntry.count >= 3, CashBookEntry.count.to_s
  cash_in = CashBookEntry.where(direction: "in").sum(:amount)
  cash_out = CashBookEntry.where(direction: "out").sum(:amount)
  assert "cash in exceeds cash out", cash_in > cash_out, "in #{money(cash_in)} / out #{money(cash_out)}"

  receivable = Business.account(Business::RECEIVABLE_ACCOUNT_CODE)
  assert "receivable control holds the balance", receivable.balance.abs > 0, money(receivable.balance)

  puts "\n== cancellation =="
  sale.cancel!("customer changed mind")
  assert "cancel restores stock", unit.reload.available?
  assert "cancel removes installment plans", sale.installment_plans.reload.empty? || sale.reload.cancelled?

  raise ActiveRecord::Rollback
  ensure
    Current.reset!
  end
end

puts "\nall finance smoke checks passed"
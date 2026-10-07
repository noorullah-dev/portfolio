# Bulk demo data layered on top of the baseline seed in db/seeds.rb.
#
#   bin/rails db:seed                                 # baseline + bulk volume
#   SEED_VOLUME=0 bin/rails db:seed                   # baseline only
#   SEED_SALES=400 SEED_CUSTOMERS=600 bin/rails db:seed
#
# Every section tops its own table up to a target instead of appending a fixed
# batch, so the seed converges: running it twice does not duplicate rows, and
# raising a target only adds the difference.
#
# All rows are written inside the shop admin's Current context (the caller
# wraps this in with_tenant), so they carry the right business_id/branch_id
# exactly like a real request.

VOLUME_TARGETS = {
  users: 6,
  customers: 250,
  stock_units: 320,
  purchases: 50,
  sales: 150,
  quotations: 40,
  bookings: 25,
  expenses: 120,
  vouchers: 60,
  journals: 40,
  transfers: 6
}.freeze

VOLUME_FIRST_NAMES = %w[
  Ali Hamza Usman Fahad Adeel Zeeshan Talha Bilal Saad Osama Danish Faisal
  Rehan Kamran Asif Naveed Shahzad Imran Tariq Junaid Waqar Salman Arslan
  Hammad Moiz Yasir Ahsan Farhan Mudassar Noman Ayesha Fatima Hina Sana
  Mariam Zoya Rabia Nimra Sara Iqra Anum Sidra Kiran
].freeze

VOLUME_LAST_NAMES = %w[
  Raza Khan Mehmood Butt Cheema Malik Sheikh Chaudhry Qureshi Gillani Hashmi
  Saddiqui Ansari Javed Iqbal Akhtar Yousaf Nawaz Mirza Abbasi Warraich
  Bhatti Sandhu Gill Awan Khokhar Ghauri Shahid Mehmood Akram Rasheed
].freeze

VOLUME_COMPANIES = %w[
  Sunrise Motors City Wheels Auto House Prime Cars Dream Motors Wheel Traders
  Metro Autos Car Bazaar Auto Care Motors National Motors Highway Wheels
].freeze

VOLUME_CITIES = %w[
  Lahore Karachi Faisalabad Multan Rawalpindi Gujranwala Sialkot Bahawalpur
  Sargodha Peshawar Islamabad Rahim Yar Khan Okara Jhang Sheikhupura
].freeze

VOLUME_STREETS = %w[
  Main Street Mall Road GT Road College Road Bank Square Market Road
  Liberty Chowk Jinnah Road Civil Lines Model Town Station Road Grain Market
].freeze

VOLUME_COLOURS = %w[White Black Silver Grey Red Blue Pearl White Champagne
                     Dark Blue Green Bronze].freeze

VOLUME_REG_PREFIXES = %w[LES ISB RWP LHR HYD MUL FSD SGD BHW RYK OKR].freeze

VOLUME_BANKS = %w[HBL UBL MCB Allied Bank Bank Alfalah Standard Chartered
                   Meezan Bank Habib Metro Faysal Bank].freeze

VOLUME_STAFF_ROLES = %w[branch_manager accountant cashier recovery_officer].freeze

VOLUME_PHONE_PREFIXES = %w[
  300 301 302 303 304 310 311 312 321 322 331 332 333 341 345 347 355 356
].freeze

VOLUME_EXPENSE_NOTES = [
  "Office stationery", "Fuel for delivery bike", "Generator diesel",
  "Internet and phone bill", "Staff tea and snacks", "Vehicle wash",
  "Print and photocopy", "Courier charges", "Security guard salary",
  "Electricity bill", "Water supply", "Repairs and maintenance",
  "Newspaper subscription", "Bank service charges", "Refreshment for customers"
].freeze

VOLUME_JOURNAL_NOTES = [
  "Monthly electricity adjustment", "Depreciation entry", "Bank charges posting",
  "Salary accrual", "Advance to supplier adjustment", "Freight expense reclass",
  "Utility advance set off", "Petty cash top up"
].freeze

# One bad row must not abort a bulk run - the seeder reports it and moves on.
def volume_step(label)
  yield
rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
  warn "  ! #{label} skipped: #{e.message.to_s.truncate(160)}"
  nil
end

def volume_target(key)
  ENV.fetch("SEED_#{key.to_s.upcase}", VOLUME_TARGETS.fetch(key)).to_i
end

def volume_needed(scope, key)
  [volume_target(key) - scope.count, 0].max
end

def pick(list, rng)
  return nil if list.blank?

  list[rng.rand(list.size)]
end

def volume_phone(rng)
  "0#{pick(VOLUME_PHONE_PREFIXES, rng)}-#{format('%07d', rng.rand(1_000_000...10_000_000))}"
end

def volume_cnic(rng)
  "35202-#{format('%07d', rng.rand(1_000_000...10_000_000))}-#{rng.rand(1..9)}"
end

def volume_date(rng, from, to)
  Date.current - rng.rand(from..to)
end

def seed_volume_users(business, owner, rng, branch, locations)
  needed = volume_needed(User.where(business_id: business.id), :users)
  return 0 if needed <= 0

  created = 0
  needed.times do |i|
    role = VOLUME_STAFF_ROLES[i % VOLUME_STAFF_ROLES.size]
    username = "#{role.to_s.sub(/_.*/, '')}#{i + 1}"
    next if User.exists?(username: username)

    volume_step("user #{username}") do
      user = User.create!(
        username: username,
        full_name: "#{pick(VOLUME_FIRST_NAMES, rng)} #{pick(VOLUME_LAST_NAMES, rng)}",
        role: role,
        business: business,
        branch: branch,
        password: "staff123",
        status: "active",
        must_change_password: false,
        provisioned_by: owner
      )
      if role == "recovery_officer" && locations.any?
        UserLocation.find_or_create_by!(user: user, location: pick(locations, rng))
      end
      created += 1
    end
  end
  created
end

def seed_volume_customers(rng, locations, agents)
  needed = volume_needed(Customer.shop, :customers)
  return 0 if needed <= 0

  created = 0
  needed.times do |i|
    volume_step("customer #{i + 1}") do
      first = pick(VOLUME_FIRST_NAMES, rng)
      last = pick(VOLUME_LAST_NAMES, rng)
      company = rng.rand < 0.15
      agent = agents.any? && rng.rand < 0.4 ? pick(agents, rng) : nil

      Customer.create!(
        name: company ? "#{pick(VOLUME_COMPANIES, rng)} #{pick(VOLUME_CITIES, rng)}" : "#{first} #{last}",
        father_name: "#{pick(VOLUME_FIRST_NAMES, rng)} #{last}",
        cnic: rng.rand < 0.7 ? volume_cnic(rng) : nil,
        phone: volume_phone(rng),
        alt_phone: rng.rand < 0.3 ? volume_phone(rng) : nil,
        address: "#{1 + (i % 900)} #{pick(VOLUME_STREETS, rng)}, #{pick(VOLUME_CITIES, rng)}",
        city: pick(VOLUME_CITIES, rng),
        customer_type: company ? "company" : "individual",
        business_name: company ? "#{pick(VOLUME_COMPANIES, rng)}" : nil,
        email: company ? nil : "#{first.downcase}.#{last.downcase}#{i + 1}@example.com",
        credit_limit: pick([0, 0, 0, 500_000, 1_000_000, 1_500_000], rng),
        opening_balance: rng.rand < 0.2 ? rng.rand(1..20) * 5_000 : 0,
        agent: agent,
        location: locations.any? ? pick(locations, rng) : nil,
        status: "active",
        remarks: rng.rand < 0.2 ? "Volume seeded customer" : nil
      )
      created += 1
    end
  end
  created
end

def seed_volume_purchases(rng, admin, tag, pairs, suppliers, modes)
  needed = volume_needed(Purchase.shop, :purchases)
  return 0 if needed <= 0 || pairs.empty? || suppliers.empty?

  created = 0
  paid = 0
  needed.times do |i|
    purchase = nil
    volume_step("purchase #{i + 1}") do
      supplier = pick(suppliers, rng)
      mode = pick(modes, rng)
      purchase = Purchase.new(
        purchase_date: volume_date(rng, 1, 300),
        supplier: supplier,
        payment_mode: mode,
        invoice_no: format("INV-%s-%05d", tag, Purchase.unscoped.count + i + 1),
        payment_type: rng.rand < 0.5 ? "cash" : "credit",
        notes: "Volume seed purchase",
        created_by: admin
      )

      rng.rand(1..3).times do |li|
        product, variant = pick(pairs, rng)
        cost = variant.purchase_price.to_d.positive? ? variant.purchase_price.to_d : rng.rand(450..950) * 10_000
        seq = StockUnit.unscoped.count + (i * 4) + li + 1
        purchase.items.build(
          product: product,
          variant: variant,
          description: variant.display_name,
          qty: 1,
          unit_price: cost,
          create_stock_unit: true,
          engine_no: format("%s-PUR-ENG-%06d", tag, seq),
          chassis_no: format("%s-PUR-CHS-%06d", tag, seq)
        )
      end

      purchase.save!
      created += 1

      next unless purchase.total_amount.to_d.positive? && rng.rand < 0.6

      purchase.record_payment!(
        amount: (purchase.total_amount * rng.rand(0.2..0.8)).round(2),
        payment_date: purchase.purchase_date + rng.rand(1..20),
        payment_mode: mode,
        reference: format("SP-%s-%05d", tag, paid + 1),
        created_by: admin
      )
      paid += 1
    end
  end
  created
end

def seed_volume_stock(rng, tag, pairs)
  needed = volume_needed(StockUnit.shop, :stock_units)
  return 0 if needed <= 0 || pairs.empty?

  start = StockUnit.unscoped.count
  created = 0
  needed.times do |i|
    seq = start + i + 1
    volume_step("stock unit #{seq}") do
      product, variant = pick(pairs, rng)
      cost = variant.purchase_price.to_d.positive? ? variant.purchase_price.to_d : rng.rand(450..950) * 10_000
      list_price = variant.sale_price.to_d.positive? ? variant.sale_price.to_d : cost * 1.18

      StockUnit.create!(
        product: product,
        variant: variant,
        engine_no: format("%s-VOL-ENG-%06d", tag, seq),
        chassis_no: format("%s-VOL-CHS-%06d", tag, seq),
        challan_no: format("CH-%d-%06d", Date.current.year, seq),
        reg_no: rng.rand < 0.6 ? format("%s-%05d", pick(VOLUME_REG_PREFIXES, rng), seq) : nil,
        serial_no: format("SN-%s-%06d", tag, seq),
        biometric: rng.rand < 0.5 ? "true" : nil,
        colour: pick(VOLUME_COLOURS, rng),
        warranty_months: pick([0, 12, 12, 24, 36], rng),
        cost_price: cost,
        sale_price: list_price.round(-2),
        status: "available",
        date_added: volume_date(rng, 1, 240),
        remarks: "Volume seed stock"
      )
      created += 1
    end
  end
  created
end

def seed_volume_sales(rng, admin, tag, agents, cash_mode, bank_mode)
  needed = volume_needed(Sale.shop, :sales)
  return { sales: 0, payments: 0, extras: 0 } if needed <= 0

  customers = Customer.shop.order(:id).to_a
  return { sales: 0, payments: 0, extras: 0 } if customers.empty?

  available = StockUnit.shop.available.order(:id).to_a
  banks = VOLUME_BANKS
  created = 0
  payments = 0
  extras = 0
  cheque_seq = PostDatedCheque.unscoped.count

  needed.times do |i|
    volume_step("sale #{i + 1}") do
      stock = available.shift
      credit = rng.rand < 0.65
      base = stock ? stock.sale_price.to_d : rng.rand(450..950) * 10_000
      total = (base * rng.rand(0.95..1.12)).round(-3)
      total = 250_000 if total.to_i <= 0
      months = credit ? pick([12, 12, 18, 24], rng) : 0
      down = credit ? (total * rng.rand(0.15..0.4)).round(-3) : 0
      down = 0 if down.to_i >= total.to_i

      sale = Sale.create!(
        customer: pick(customers, rng),
        sale_date: volume_date(rng, 1, 210),
        sale_type: credit ? "credit" : "cash",
        stock_unit: stock,
        product: stock&.product,
        variant: stock&.variant,
        reg_no: stock&.reg_no,
        total_amount: total,
        discount: 0,
        down_payment: down,
        months: months,
        payment_mode: rng.rand < 0.75 ? cash_mode : bank_mode,
        agent: credit && rng.rand < 0.5 ? pick(agents, rng) : nil,
        late_fee_type: pick(%w[none none none percent fixed], rng),
        cost_amount: stock ? stock.cost_price : (total * 0.82).round(-3),
        notes: "Volume seed sale",
        created_by: admin
      )
      created += 1
      extras += 1 if volume_sale_extras(sale, stock, rng, admin, cheque_seq, banks, cash_mode, bank_mode)
      cheque_seq += 3

      next unless credit

      payments += volume_sale_payments(sale, rng, admin, cash_mode, bank_mode)
    end
  end

  { sales: created, payments: payments, extras: extras }
end

# Collection history: settle the instalments that are already past due, with the
# odd short payment and the odd missed month so the trackers have something to
# show. Only ever touches the sale that was just created, so a re-run cannot
# double-post a payment.
def volume_sale_payments(sale, rng, admin, cash_mode, bank_mode)
  count = 0

  sale.installment_plans.unpaid.chronological.each do |plan|
    break if plan.due_date > Date.current
    break if rng.rand < 0.12

    amount = plan.remaining
    amount = (amount * rng.rand(0.4..0.9)).round(2) if rng.rand < 0.25
    next unless amount.to_d.positive?

    payment_date = [plan.due_date + rng.rand(0..7), Date.current].min

    volume_step("payment for #{sale.sale_no}") do
      InstallmentPayment.register!(
        sale: sale,
        amount: amount,
        payment_date: payment_date,
        payment_mode: rng.rand < 0.7 ? cash_mode : bank_mode,
        reference: format("VOL-%s-%02d", sale.sale_no, plan.installment_no),
        remarks: "Volume seed collection",
        created_by: admin
      )
      count += 1
    end
  end

  count
end

# Cheques, registration tracking, vehicle documents, reminders and recovery
# visits for a freshly created sale.
def volume_sale_extras(sale, stock, rng, admin, cheque_seq, banks, cash_mode, bank_mode)
  made = false

  if sale.credit_sale? && sale.installment_plans.any?
    sale.installment_plans.unpaid.chronological.first(3).each_with_index do |plan, index|
      volume_step("cheque for #{sale.sale_no}") do
        PostDatedCheque.create!(
          cheque_no: format("%s%07d", sale.sale_no.delete("-"), cheque_seq + index + 1),
          bank_name: pick(banks, rng),
          customer: sale.customer,
          sale: sale,
          account_no: format("%04d%08d", rng.rand(1..9999), rng.rand(10_000_000)),
          amount: plan.amount,
          cheque_date: plan.due_date,
          covered_month: plan.due_date.beginning_of_month,
          status: pick(%w[pending pending pending deposited cleared bounced], rng),
          remarks: "Volume seed cheque",
          created_by: admin
        )
        made = true
      end
    end
  end

  if stock && rng.rand < 0.7
    submitted = [sale.sale_date + rng.rand(2..12), Date.current - 1].min
    expected = submitted + rng.rand(15..45)
    received = expected < Date.current && rng.rand < 0.6

    volume_step("registration for #{sale.sale_no}") do
      RegistrationTracking.find_or_create_by!(sale: sale) do |tracking|
        tracking.customer = sale.customer
        tracking.engine_no = stock.engine_no
        tracking.chassis_no = stock.chassis_no
        tracking.submitted_date = submitted
        tracking.expected_return_date = expected
        tracking.status = if received
                            "received"
                          elsif expected < Date.current
                            pick(%w[submitted at_office], rng)
                          else
                            pick(%w[pending submitted], rng)
                          end
        tracking.letter_received = received
        tracking.received_date = received ? expected + rng.rand(0..5) : nil
        tracking.remarks = "Volume seed registration"
        tracking.created_by = admin
      end
      made = true
    end
  end

  %w[letter warranty_book].each do |type|
    volume_step("#{type} for #{sale.sale_no}") do
      VehicleDocument.create!(
        sale: sale,
        customer: sale.customer,
        document_type: type,
        received: rng.rand < 0.6,
        expected_date: sale.sale_date + 30,
        reference_no: format("DOC-%s-%06d", sale.sale_no.delete("-"), rng.rand(100_000..999_999)),
        remarks: "Volume seed document",
        created_by: admin
      )
      made = true
    end
  end

  due = sale.installment_plans.unpaid.due_before(Date.current).order(:due_date).first
  if due && rng.rand < 0.5
    volume_step("reminder for #{sale.sale_no}") do
      InstallmentReminder.create!(
        installment_plan: due,
        sale: sale,
        customer: sale.customer,
        channel: pick(%w[sms whatsapp call], rng),
        sent_at: Time.current - rng.rand(1..20).days,
        remarks: "Volume seed reminder",
        created_by: admin
      )
      made = true
    end
  end

  if sale.overdue_amount.to_d.positive? && rng.rand < 0.6
    volume_step("recovery for #{sale.sale_no}") do
      CreditRecovery.create!(
        recovery_date: volume_date(rng, 0, 25),
        sale: sale,
        customer: sale.customer,
        agreed_date: Date.current + rng.rand(1..15),
        amount: [sale.overdue_amount, 25_000].max.round(-2),
        payment_mode: rng.rand < 0.7 ? cash_mode : bank_mode,
        reference: format("REC-%s", sale.sale_no),
        remarks: "Volume seed recovery visit",
        created_by: admin
      )
      made = true
    end
  end

  made
end

def seed_volume_quotations(rng, admin, pairs, customers)
  needed = volume_needed(Quotation.shop, :quotations)
  return 0 if needed <= 0 || pairs.empty?

  created = 0
  needed.times do |i|
    volume_step("quotation #{i + 1}") do
      product, variant = pick(pairs, rng)
      price = variant.sale_price.to_d.positive? ? variant.sale_price.to_d : rng.rand(450..950) * 10_000
      price = (price * rng.rand(0.97..1.1)).round(-3)
      down = (price * rng.rand(0.1..0.4)).round(-3)

      Quotation.create!(
        customer: pick(customers, rng),
        product: product,
        variant: variant,
        customer_name: nil,
        quotation_date: volume_date(rng, 0, 75),
        valid_until: Date.current + rng.rand(-20..40),
        months: pick([0, 12, 18, 24], rng),
        sale_price: price,
        down_payment: down,
        status: pick(%w[draft sent sent accepted rejected], rng),
        notes: "Volume seed quotation",
        created_by: admin
      )
      created += 1
    end
  end
  created
end

def seed_volume_bookings(rng, admin, pairs, customers, agents, cash_mode)
  needed = volume_needed(AdvanceBooking.shop, :bookings)
  return 0 if needed <= 0 || pairs.empty?

  created = 0
  needed.times do |i|
    volume_step("booking #{i + 1}") do
      product, variant = pick(pairs, rng)
      price = variant.sale_price.to_d.positive? ? variant.sale_price.to_d : rng.rand(450..950) * 10_000
      price = (price * rng.rand(0.97..1.1)).round(-3)
      advance = (price * rng.rand(0.1..0.3)).round(-3)

      booking = AdvanceBooking.create!(
        customer: pick(customers, rng),
        product: product,
        variant: variant,
        booking_date: volume_date(rng, 0, 60),
        expected_delivery: Date.current + rng.rand(10..75),
        total_amount: price,
        advance_amount: advance,
        sale_type: "credit",
        months: pick([12, 18, 24], rng),
        agent: rng.rand < 0.4 ? pick(agents, rng) : nil,
        status: pick(%w[confirmed confirmed confirmed delivered], rng),
        remarks: "Volume seed booking",
        created_by: admin
      )

      next if advance.to_d <= 0

      booking.record_payment!(
        amount: advance,
        payment_date: booking.booking_date,
        payment_mode: cash_mode,
        remarks: "Advance received",
        created_by: admin
      )
      created += 1
    end
  end
  created
end

def seed_volume_expenses(rng, admin, categories, accounts, modes)
  needed = volume_needed(Expense.shop, :expenses)
  return 0 if needed <= 0

  expense_accounts = accounts.select { |account| account.account_type == "expense" }
  expense_accounts = accounts if expense_accounts.empty?
  created = 0

  needed.times do |i|
    volume_step("expense #{i + 1}") do
      Expense.create!(
        expense_date: volume_date(rng, 0, 180),
        category: pick(categories, rng),
        description: "#{pick(VOLUME_EXPENSE_NOTES, rng)} ##{i + 1}",
        amount: pick([1_500, 2_500, 4_000, 6_500, 9_000, 12_000, 18_500, 25_000, 40_000, 75_000], rng),
        payment_mode: pick(modes, rng),
        account: pick(expense_accounts, rng),
        reference: format("EXP-%05d", Expense.unscoped.count + i + 1),
        added_by: admin
      )
      created += 1
    end
  end
  created
end

def seed_volume_vouchers(rng, admin, customers, suppliers, modes)
  needed = volume_needed(Voucher.shop, :vouchers)
  return 0 if needed <= 0

  created = 0
  needed.times do |i|
    volume_step("voucher #{i + 1}") do
      kind = pick(%w[receipt payment], rng)
      party = kind == "receipt" ? pick(customers, rng) : pick(suppliers, rng)
      party_type = kind == "receipt" ? "Customer" : "Supplier"

      Voucher.create!(
        kind: kind,
        voucher_date: volume_date(rng, 0, 120),
        party_type: party ? party_type : "Other",
        party_id: party&.id,
        party_name: party ? party.name : pick(VOLUME_COMPANIES, rng),
        amount: pick([5_000, 10_000, 25_000, 50_000, 80_000, 120_000, 250_000], rng),
        payment_mode: pick(modes, rng),
        reference: format("VCH-%05d", Voucher.unscoped.count + i + 1),
        remarks: "Volume seed voucher",
        created_by: admin
      )
      created += 1
    end
  end
  created
end

def seed_volume_journals(rng, admin, accounts)
  needed = volume_needed(JournalVoucher.shop, :journals)
  return 0 if needed <= 0 || accounts.size < 2

  debit_accounts = accounts.reject { |account| account.account_type == "income" }
  credit_accounts = accounts
  created = 0

  needed.times do |i|
    volume_step("journal voucher #{i + 1}") do
      voucher = JournalVoucher.new(
        voucher_date: volume_date(rng, 0, 150),
        description: "#{pick(VOLUME_JOURNAL_NOTES, rng)} ##{i + 1}",
        reference: format("JVOL-%05d", JournalVoucher.unscoped.count + i + 1),
        status: "draft",
        posted_by: admin
      )
      amount = pick([10_000, 25_000, 40_000, 60_000, 90_000, 150_000], rng)
      voucher.lines.build(account: pick(debit_accounts, rng), debit: amount, remarks: "Debit side")
      voucher.lines.build(account: pick(credit_accounts, rng), credit: amount, remarks: "Credit side")
      voucher.save!
      voucher.post!(user: admin)
      created += 1
    end
  end
  created
end

def seed_volume_commissions(rng, admin, modes)
  pending = AgentCommission.shop.where(status: %w[pending partial])
                           .where.not(id: AgentCommissionPayment.select(:agent_commission_id))
                           .order(:id).to_a
  return 0 if pending.empty?

  paid = 0
  pending.first(40).each do |commission|
    next unless commission.balance.to_d.positive?
    next if rng.rand < 0.5

    volume_step("commission #{commission.sale_no}") do
      amount = (commission.balance * pick([1.0, 1.0, 0.5, 0.75], rng)).round(2)
      next unless amount.to_d.positive?

      AgentCommissionPayment.create!(
        agent_commission: commission,
        payment_date: volume_date(rng, 0, 60),
        amount: amount,
        payment_mode: pick(modes, rng),
        remarks: "Volume seed commission payment",
        created_by: admin
      )
      commission.update!(paid_amount: commission.paid_amount.to_d + amount)
      paid += 1
    end
  end
  paid
end

def seed_volume_transfers(rng, admin, customers)
  needed = volume_needed(AccountTransfer.shop, :transfers)
  return 0 if needed <= 0 || customers.size < 2

  created = 0
  needed.times do |i|
    volume_step("transfer #{i + 1}") do
      from = customers.sample(random: rng)
      to = customers.sample(random: rng)
      next if from.nil? || to.nil? || from == to

      AccountTransfer.create!(
        transfer_date: volume_date(rng, 0, 90),
        customer: from,
        from_customer: from,
        to_customer: to,
        remaining_balance: rng.rand(5..60) * 25_000,
        fee: pick([0, 2_000, 5_000, 10_000], rng),
        status: pick(%w[pending approved approved rejected], rng),
        remarks: "Volume seed transfer",
        created_by: admin
      )
      created += 1
    end
  end
  created
end

# Entry point - called from db/seeds.rb inside the shop admin's tenant context.
def seed_volume(business, admin, owner)
  rng = Random.new((business.id || 1) * 9_771 + 11)
  tag = business.slug.to_s.gsub(/[^a-z0-9]/i, "").to_s.upcase.first(3).presence || "SHO"

  locations = Location.shop.order(:id).to_a
  agents = Agent.shop.order(:id).to_a
  suppliers = Supplier.shop.order(:id).to_a
  customers = Customer.shop.order(:id).to_a
  accounts = ChartOfAccount.shop.order(:code).to_a
  categories = ExpenseCategory.shop.order(:id).to_a
  modes = PaymentMode.shop.cash_first.to_a
  cash_mode = modes.find(&:is_cash?) || modes.first
  bank_mode = modes.reject(&:is_cash?).first || cash_mode
  branches = Branch.shop.where(status: "active").order(:id).to_a
  branch = branches.find(&:is_default?) || branches.first
  pairs = Product.shop.active.includes(:variants).flat_map do |product|
    product.variants.reject { |variant| variant.status.to_s != "active" }.map { |variant| [product, variant] }
  end

  counts = {}
  counts[:users] = seed_volume_users(business, owner, rng, branch, locations)
  counts[:customers] = seed_volume_customers(rng, locations, agents)
  counts[:purchases] = seed_volume_purchases(rng, admin, tag, pairs, suppliers, modes)
  counts[:stock] = seed_volume_stock(rng, tag, pairs)

  sales = seed_volume_sales(rng, admin, tag, agents, cash_mode, bank_mode)
  counts[:sales] = sales[:sales]
  counts[:collections] = sales[:payments]

  counts[:quotations] = seed_volume_quotations(rng, admin, pairs, customers)
  counts[:bookings] = seed_volume_bookings(rng, admin, pairs, customers, agents, cash_mode)
  counts[:expenses] = seed_volume_expenses(rng, admin, categories, accounts, modes)
  counts[:vouchers] = seed_volume_vouchers(rng, admin, customers, suppliers, modes)
  counts[:journals] = seed_volume_journals(rng, admin, accounts)
  counts[:commissions] = seed_volume_commissions(rng, admin, modes)
  counts[:transfers] = seed_volume_transfers(rng, admin, customers)

  counts.select { |_key, value| value.to_i.positive? }
        .map { |key, value| "#{value} #{key}" }.join(", ")
end

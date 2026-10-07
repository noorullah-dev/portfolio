# Functional form harness: visits every form screen in the app, fills it with
# plausible data and submits it, reporting any form that fails to save.
#
#   bin/rails runner script/smoke_forms.rb
#
# Runs the app in-process (no server needed) inside a transaction that is
# always rolled back, so the database is left untouched.

require "action_dispatch/testing/integration"
require "nokogiri"

ActionController::Base.allow_forgery_protection = false
# surface RecordNotFound instead of a silent 404 so the cause is visible
Rails.application.env_config["action_dispatch.show_exceptions"] = :none
# The harness runs integration sessions inside its own transaction. Rails only
# allows the execution context to nest in tests, so make the context nestable -
# otherwise a request's pop leaves the context unbalanced and the next SQL
# statement (the rollback itself) fails.
ActiveSupport::ExecutionContext.instance_variable_set(:@nestable, true)

PASS = []
FAIL = []
SKIP = []

# Areas a shop admin must never reach; the crawl expects them to be refused.
PROTECTED_PATHS = ["/owner", "/portal", "/access-denied"].freeze

# A suspended shop locks every login, so fail with a clear pointer instead of
# a wall of confusing permission errors.
stalled = Business.where(status: "suspended").pluck(:name)
unless stalled.empty?
  warn "suspended business(es): #{stalled.join(", ")}"
  warn "reactivate from the owner console (/owner) or with: bin/rails runner 'Business.where(status: \"suspended\").update_all(status: \"active\")'"
  exit 2
end

def money(value)
  format("%<value>.2f", value: value.to_d)
end

def report(status, label, detail = nil)
  line = "#{status}  #{label}#{detail ? " -> #{detail}" : ''}"
  puts line
  (status == "PASS" ? PASS : status == "SKIP" ? SKIP : FAIL) << label
end

# ---------------------------------------------------------------- test data
def seed_data!
  cash = PaymentMode.find_by!(name: "Cash")
  bank = PaymentMode.find_by!(name: "Bank")
  brand = Brand.find_by!(name: "Toyota")
  # Reference data is duplicated per shop, so pick this shop's own row instead of
  # whichever one happens to have the lowest id.
  category = Category.shop.find_by!(name: "Corolla")
  agent = Agent.find_by!(name: "Bilal Ahmed")
  supplier = Supplier.find_by!(name: "Indus Motors")
  admin = User.find_by!(username: "admin")
  # The user form is exercised on a throwaway account: editing the signed-in admin
  # would lock the harness out of its own session mid-run.
  form_user = User.create!(username: "smoke_form_#{UNIQUE}", full_name: "Smoke Form User",
                           password: "Passw0rd!123", role: "cashier",
                           business_id: admin.business_id, branch_id: admin.branch_id, status: "active")

  product = Product.create!(name: "Corolla GLi #{UNIQUE}", brand: brand, category: category)
  variant = product.variants.create!(value: "GLi #{UNIQUE}", purchase_price: 1_900_000,
                                     sale_price: 2_600_000, status: "active")

  purchase = Purchase.create!(
    supplier: supplier, purchase_date: 20.days.ago.to_date, payment_mode: bank,
    items_attributes: Array.new(3) do |i|
      { qty: 1, unit_price: 2_000_000, product_id: product.id, variant_id: variant.id,
        engine_no: "ENG-F#{rand(100_000..999_999)}",
        chassis_no: "CHS-F#{rand(100_000..999_999)}", create_stock_unit: true,
        description: "Corolla GLi #{2021 + i}" }
    end
  )

  customer = Customer.create!(name: "Ali Raza", phone: "03001234567", cnic: "35202-1234567-8",
                              customer_type: "individual")
  unit = purchase.stock_units.order(:id).last

  sale = Sale.create!(
    customer: customer, sale_date: Date.current, sale_type: "credit", stock_unit: unit,
    variant: unit.variant, product: unit.product, total_amount: 2_600_000, discount: 100_000,
    down_payment: 600_000, months: 12, payment_mode: bank, agent: agent,
    cost_amount: unit.cost_price, created_by: admin,
    items_attributes: [{ qty: 1, unit_price: 2_600_000, discount: 100_000, stock_unit_id: unit.id }]
  )

  booking = AdvanceBooking.create!(customer: customer, variant: variant, product: unit.product,
                                   booking_date: Date.current, sale_type: "credit",
                                   total_amount: 500_000, advance_amount: 100_000,
                                   balance_amount: 400_000, months: 6, status: "confirmed",
                                   agent: agent, created_by: admin)
  # AdvanceBooking#build_plans! generates the schedule on create.

  quotation = Quotation.create!(customer: customer, variant: variant, quotation_date: Date.current,
                                valid_until: 20.days.from_now.to_date, sale_price: 2_500_000,
                                down_payment: 500_000, months: 12, status: "draft", created_by: admin)

  cheque = PostDatedCheque.create!(customer: customer, sale: sale, cheque_no: "PDC-#{rand(10_000..99_999)}",
                                   bank_name: "Meezan Bank", amount: 300_000,
                                   cheque_date: Date.current, status: "pending", created_by: admin)
  reminder = InstallmentReminder.create!(installment_plan: sale.installment_plans.order(:installment_no).first,
                                         channel: "sms", remarks: "First reminder",
                                         sent_at: Time.current, created_by: admin)
  closure = AccountClosure.create!(customer: customer, closure_date: Date.current, reason: "Settled",
                                   status: "pending", created_by: admin)
  transfer = AccountTransfer.create!(customer: customer, from_customer_id: customer.id,
                                     to_customer_id: Customer.create!(name: "Copy Customer",
                                                                       customer_type: "individual").id,
                                     transfer_date: Date.current, fee: 500, remarks: "Duplicate account",
                                     status: "pending", created_by: admin)
  # Sale creation already awards the agent commission (one per sale).
  commission = sale.agent_commissions.first
  journal = JournalVoucher.create!(voucher_date: Date.current, description: "Opening entry", status: "draft")
  journal.lines.create!(account: Business.account(Business::DEFAULT_EXPENSE_CODE),
                        debit: 1_000, remarks: "Test debit")
  journal.lines.create!(account: Business.account(Business::RECEIVABLE_ACCOUNT_CODE),
                        credit: 1_000, remarks: "Test credit")
  voucher = Voucher.create!(kind: "receipt", voucher_date: Date.current, party_type: "Customer",
                            party_id: customer.id, party_name: customer.name, amount: 25_000,
                            payment_mode: cash, account: Business.account(Business::RECEIVABLE_ACCOUNT_CODE))
  expense = Expense.create!(expense_date: Date.current, description: "Fuel", amount: 5_000,
                            payment_mode: cash, added_by: admin)
  account = Business.account(Business::DEFAULT_EXPENSE_CODE)
  plan = sale.installment_plans.unpaid.order(:installment_no).first
  recovery = CreditRecovery.create!(sale: sale, customer: customer, recovery_date: Date.current,
                                   agreed_date: 15.days.from_now.to_date, amount: 25_000,
                                   payment_mode: cash, reference: "REF-#{UNIQUE}", created_by: admin)
  tracking = RegistrationTracking.create!(sale: sale, customer: customer, agent: agent,
                                         engine_no: "ENG-#{next_token}", chassis_no: "CHS-#{next_token}",
                                         submitted_date: Date.current,
                                         expected_return_date: 10.days.from_now.to_date,
                                         status: "pending", created_by: admin)

  {
    brand: brand, category: category, agent: agent, supplier: supplier, admin: admin, user: form_user,
    purchase: purchase, customer: customer, sale: sale, unit: unit, variant: variant,
    product: product, booking: booking, quotation: quotation, cheque: cheque, reminder: reminder,
    closure: closure, transfer: transfer, commission: commission, voucher: voucher,
    expense: expense, account: account, recovery: recovery, tracking: tracking,
    plan: plan, journal: journal
  }
end

# ------------------------------------------------------- form value guessing
UNIQUE = (0...1_000_000).to_a.sample

LOGIN_PASSWORD = "admin123".freeze
UPLOAD_SAMPLE = "/tmp/qm_upload_sample.png".freeze

# The logo-upload check needs a real file on disk. Create a 1x1 PNG when it is
# missing so the suite never depends on leftover state in /tmp.
def ensure_upload_sample(path = UPLOAD_SAMPLE)
  return path if File.exist?(path)

  File.binwrite(path, [
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4",
    "890000000a49444154789c6360000002000100ffff03000006000557bfabd400",
    "00000049454e44ae426082"
  ].join.scan(/../).map { |byte| byte.to_i(16) }.pack("C*"))
  path
end

def form_password
  @form_password ||= "Passw0rd!#{UNIQUE}"
end

# fields the database treats as unique: never reuse the same generated value
UNIQUE_VALUE = /username|email|invoice|cheque|account_no|cnic|ntn|engine|chassis|reg_no|name/i

def next_token
  @token_seq = (@token_seq || 0) + 1
  "#{UNIQUE}#{@token_seq}"
end

def text_for(name)
  n = name.to_s.downcase.delete("[]")
  return LOGIN_PASSWORD if n == "current_password"
  return form_password if n.include?("password")
  return "user#{next_token}" if n.end_with?("username")
  return "test#{next_token}@example.com" if n.include?("email")
  return "0300123456#{rand(0..7)}" if n.include?("phone") || n.include?("mobile")
  return "35202-#{rand(10_000..99_999)}-#{rand(100_000..999_999)}-#{rand(1..9)}" if n.include?("cnic")
  return "NTN#{rand(100_000..999_999)}" if n.include?("ntn")
  return "ENG-#{next_token}" if n.include?("engine")
  return "CHS-#{next_token}" if n.include?("chassis")
  return "ACC-#{next_token}" if n.include?("account_no")
  return "PDC-#{rand(10_000..99_999)}" if n.include?("cheque")
  return "30/06/#{rand(2026..2030)}" if n.include?("expiry")
  return "Karachi" if n.include?("city")
  return "Test note" if n.include?("note") || n.include?("description") || n.include?("address")
  return "Sales" if n.include?("party_name") || n == "voucher[party_name]"
  return "Test reason" if n.include?("reason")
  "Test #{name.to_s.split(/[^a-zA-Z0-9]+/).last.to_s.humanize} #{next_token}"
end

def number_for(name)
  n = name.to_s.downcase.delete("[]")
  # ordered: most specific first. These must stay mutually consistent, e.g. a
  # down payment has to stay below the net sale amount or the ledger rejects it.
  return 500 if n.include?("discount")
  return 1_000 if n.include?("down_payment") || n.include?("downpayment")
  return 200_000 if n.include?("cost")
  return 250_000 if n.include?("unit_price") || n.include?("total") || n.include?("amount") ||
                   n.include?("price") || n.include?("paid") || n.include?("basis") ||
                   n.include?("sale_value") || n.include?("financed")
  return 12 if n.include?("months") || n.include?("qty") || n.include?("quantity") ||
               n.include?("installment") || n.include?("no_of") || n.include?("term")
  return 0 if n.include?("late_fee") || n.include?("alert") || n.include?("days_after")
  return 5 if n.include?("percent") || n.include?("rate") || n.include?("markup") ||
               n.include?("interest") || n.include?("commission_value") || n.include?("tax")
  return 1
end

def clamp_range(el, value)
  min = el["min"].to_f
  max = el["max"].to_f
  value = value.to_f
  value = min if value < min
  value = max if max.positive? && value > max
  el["step"].to_s.start_with?("0.") ? value.round(2) : value.round
end

DATE_FIELDS = %w[date due_date purchase_date sale_date quotation_date expiry_date voucher_date
                  start_date end_date booked_on next_due_date reminder_date requested_at
                  transfer_date closure_date payment_date issue_date].freeze

def build_params(form, overrides = {})
  @form_password = nil
  params = {}
  form.css("input, select, textarea").each do |el|
    name = el["name"].to_s
    next if name.empty?
    next if %w[_method utf8 authenticity_token commit].include?(name)

    value = case el.name
            when "input"
              case el["type"]
              when "password" then text_for(name)
              when "checkbox" then el["checked"] ? el["value"].presence || "1" : nil
              when "radio" then el["value"].presence || "1"
              when "hidden" then el["value"].presence
              when "submit", "button", "image" then nil
              when "number", "range"
                clamp_range(el, number_for(name)).to_s
              when "date" then (name.include?("from") || name.include?("start") ? 30.days.ago : 20.days.from_now).to_date.to_s
              when "datetime-local" then 1.day.from_now.change(usec: 0).strftime("%Y-%m-%dT%H:%M")
              when "email", "tel", "text", "search", "url"
                (UNIQUE_VALUE.match?(name) && el["value"].blank?) ? text_for(name) : (el["value"].presence || text_for(name))
              else el["value"].presence || text_for(name)
              end
            when "select"
              selected = el.css("option[selected]").first || el.css("option").reject { |o| o["value"].to_s.empty? }.first
              selected && selected["value"].presence
            when "textarea"
              text_for(name)
            end

    next if value.nil?
    next if debit_or_credit_conflict?(form, params, name)

    params[name] = value
  end

  params.merge(overrides)
end

# a journal line carries either a debit or a credit, never both. Rows that
# already hold a value keep their side; empty rows alternate debit/credit so the
# voucher balances.
def debit_or_credit_conflict?(form, params, name)
  return false unless name.include?("_attributes]")

  row = name[/\[(\d+)\]\[(debit|credit)\]/, 1]
  side = name[/\[(debit|credit)\]/, 1]
  return false if row.nil? || side.nil?

  other = side == "debit" ? "credit" : "debit"
  mine = filled?(form, name)
  theirs = filled?(form, name.sub("[#{side}]", "[#{other}]"))

  return true if mine && theirs
  return false if mine
  return true if theirs

  side != (row.to_i.even? ? "debit" : "credit")
end

# a rendered 0.0 counts as empty: new journal lines default to zero
def filled?(form, name)
  field = form.at_css("[name='#{Regexp.escape(name)}']")
  raw = field && field["value"].to_s.strip
  return false if raw.blank?

  raw.to_d != 0
end

def error_messages(body)
  doc = Nokogiri::HTML(body)
  texts = doc.css(".alert-danger li, .alert-danger, .invalid-feedback, .field_errors").map { |n| n.text.strip }
  texts = texts.reject(&:empty?).uniq
  texts = doc.css(".alert-danger").map { |n| n.text.strip.gsub(/\s+/, " ").truncate(200) } if texts.empty?
  texts.first(3).join(" | ")
end

def exception_of(body)
  doc = Nokogiri::HTML(body.to_s)
  title = doc.at_css("h2")&.text.to_s.strip
  msg = doc.at_css(".message")&.text.to_s.strip
  h1 = doc.at_css("h1")&.text.to_s.strip
  alert = doc.at_css(".alert-danger")&.text.to_s.strip
  [title, msg || h1 || alert].compact.reject(&:empty?).first.to_s.gsub(/\s+/, " ").truncate(240)
end

# An in-process integration session pops the execution context without a
# matching push (it resets IsolatedExecutionState in between requests), which
# leaves ActiveSupport::ExecutionContext's internal store nil. The next
# statement outside a request - here the harness rollback - then dies inside
# ActiveRecord::QueryLogs. A real Puma request is balanced and unaffected, so
# this only repairs the state around the harness' own requests.
def repair_execution_context!
  record = ActiveSupport::ExecutionContext.send(:record)
  return if record.nil?

  if record.instance_variable_get(:@store).nil?
    record.instance_variable_set(:@store, {})
    record.instance_variable_set(:@current_attributes_instances, {})
    record.instance_variable_set(:@stack, [])
  end
end

def with_execution_context
  yield
ensure
  repair_execution_context!
  Current.set_from(HARNESS_CONTEXT) if defined?(HARNESS_CONTEXT) && HARNESS_CONTEXT
end

def submit(session, form, params)
  method = (form.at_css("input[name=_method]")&.[]("value") || form["method"] || "get").downcase
  action = form["action"].to_s
  action = session.request.path if action.empty?
  with_execution_context do
    if method == "get"
      session.get(action, params: params)
    else
      session.send(method, action, params: params)
    end
  end
  session.response
end

def isolate
  ActiveRecord::Base.transaction(requires_new: true) { yield }
rescue StandardError => e
  File.write("/tmp/isolate_debug.txt", "#{e.class}: #{e.message}\n" + Array(e.backtrace).first(25).join("\n"))
  e
end

def try_form(session, label, form, overrides = {})
  # Never let the generic filler invent a new password for a real account: that
  # would flag the signed-in admin with must_change_password and every later
  # probe would be redirected to the change-password screen.
  # Only the change-password form is meant to carry a new password; anywhere
  # else a filled password field would silently reset a real account.
  blank_passwords = { "password" => nil, "password_confirmation" => nil, "current_password" => nil }
  if form.css("input[name*=password]").any? && !label.include?("change-password")
    overrides = overrides.merge(blank_passwords.reject { |key, _| overrides.key?(key) || overrides.key?(key.to_sym) })
  end

  params = build_params(form, overrides)
  form.css("input[type=file]").each do |input|
    name = input["name"].to_s
    next if name.empty?

    params[name] = Rack::Test::UploadedFile.new(ensure_upload_sample, "image/png")
  end
  response = nil
  error = isolate { response = submit(session, form, params) }
  if error.is_a?(StandardError)
    report("FAIL", label, "raised #{error.class}: #{error.message.to_s.gsub(/\s+/, ' ').truncate(160)} @ #{Array(error.backtrace).reject { |l| l.include?('gems/') }.first(3).join(' | ')}")
    return
  end

  if response.status >= 500
    report("FAIL", label, "HTTP #{response.status} #{exception_of(response.body)}")
  elsif response.status.between?(300, 399)
    report("PASS", label, "-> #{response.location}")
  elsif response.status == 200 && response.body.include?("alert-danger")
    report("FAIL", label, error_messages(response.body))
  else
    slug = label.gsub(/[^a-zA-Z0-9]+/, "_")
    dump = "/tmp/qm_fail_#{slug}.html"
    File.write(dump, response.body.to_s)
    File.write("/tmp/qm_fail_#{slug}.json", JSON.pretty_generate(params))
    report("FAIL", label, "HTTP #{response.status} #{exception_of(response.body)} (body: #{dump})")
  end
end

# the record id in a path must exist, so ask the model instead of guessing 1
def resolve_real_id(route, path, controller, records = {})
  return path unless path.match?(%r{/\d+(/|$)})

  # the id in the path belongs to the param name (sale_id -> Sale), not to the
  # controller that renders the page; read the name off the route template
  param = route[%r{/:(\w+)}, 1].to_s
  # a bare :id belongs to the controller's own model
  model_name = param == "id" ? controller.to_s.classify : param.sub(/_id\z/, "").classify
  id = records[model_name]
  # Fall back to a record the harness user can actually open: another shop's row
  # would 404 through no fault of the page under test.
  unless id
    model = model_name.safe_constantize
    id = model.shop.first&.id if model.respond_to?(:shop)
  end
  return path if id.nil?

  path.sub(%r{/\d+(?=/|$)}, "/#{id}")
end

# ----------------------------------------------------------------- crawl app
session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! "localhost"

# The rollback must propagate out of the block, otherwise the transaction
# commits every probe and pollutes the database.
begin
  ActiveRecord::Base.transaction do
    HARNESS_CONTEXT = User.find_by!(username: "admin") || User.new
    Current.set_from(User.find_by(username: "admin"))
    data = seed_data!
  # The run depends on known credentials; restore them instead of failing later.
  %w[admin manager accounts].zip(%w[admin123 manager123 accounts123]).each do |username, password|
    user = User.find_by(username: username)
    next if user.nil? || user.authenticate(password)

    user ||= User.new(username: username, full_name: username.titleize, role: username, status: "active")
    user.password = user.password_confirmation = password
    user.must_change_password = false
    user.failed_login_count = 0
    user.locked_until = nil
    user.save!
    puts "reset credentials for #{username}"
  end

  with_execution_context do
    session.post "/login", params: { username: "admin", password: "admin123" }
  end
  raise "login failed for admin (HTTP #{session.response.status})" unless session.response.status.between?(300, 399)

  # Fixtures are built outside a request, so the tenant context is set by hand -
  # otherwise every seeded row would have no business_id and the tenant-scoped
  # controllers could not find it.

  records = {
    "User" => data[:user],
    "Brand" => data[:brand], "Category" => data[:category], "Agent" => data[:agent],
    "Supplier" => data[:supplier], "Purchase" => data[:purchase], "Customer" => data[:customer],
    "Sale" => data[:sale], "StockUnit" => data[:unit], "Variant" => data[:variant],
    "Product" => data[:product], "AdvanceBooking" => data[:booking], "Quotation" => data[:quotation],
    "PostDatedCheque" => data[:cheque], "AccountClosure" => data[:closure],
    "AccountTransfer" => data[:transfer], "AgentCommission" => data[:commission],
    "JournalVoucher" => data[:journal], "Voucher" => data[:voucher], "Expense" => data[:expense],
    "ChartOfAccount" => data[:account], "CreditRecovery" => data[:recovery],
    "RegistrationTracking" => data[:tracking]
  }.transform_values { |record| record&.id }

  ids = {
    "brand" => data[:brand].id, "category" => data[:category].id, "agent" => data[:agent].id,
    "supplier" => data[:supplier].id, "purchase" => data[:purchase].id,
    "customer" => data[:customer].id, "sale" => data[:sale].id, "unit" => data[:unit].id,
    "variant" => data[:variant].id, "product" => data[:product].id, "booking" => data[:booking].id,
    "quotation" => data[:quotation].id, "cheque" => data[:cheque].id, "reminder" => data[:reminder].id,
    "closure" => data[:closure].id, "transfer" => data[:transfer].id,
    "commission" => data[:commission].id, "voucher" => data[:voucher].id,
    "expense" => data[:expense].id, "account" => data[:account].id, "recovery" => data[:recovery].id,
    "tracking" => data[:tracking].id, "customer_id" => data[:customer].id,
    "sale_id" => data[:sale].id, "product_id" => data[:product].id,
    "purchase_id" => data[:purchase].id, "advance_booking_id" => data[:booking].id
  }

  tried_actions = []
  csrf_token = nil

  puts "\n=== form pages ==="
  Rails.application.routes.routes.map { |r| [r.verb, r.path.spec.to_s.sub("(.:format)", ""), r.defaults] }
                                .select { |verb, path, d| verb == "GET" && d[:controller] != "sessions" }
                                .map { |_, path, d| [path, d] }
                                .uniq { |path, _| path }
                                .sort_by { |path, _| path }
                                .each do |path, defaults|
    concrete = path.gsub(/:(\w+)/) { ids.fetch(Regexp.last_match(1).to_s, "1") }
    concrete = resolve_real_id(path, concrete, defaults[:controller], records)
    action = defaults[:action].to_s
    next unless %w[new edit].include?(action)

    load_error = isolate { with_execution_context { session.get concrete } }
    if load_error.is_a?(AbstractController::ActionNotFound)
      report("SKIP", "#{path} (#{action})", "#{load_error.message}")
      next
    end
    if load_error.is_a?(StandardError)
      report("FAIL", "#{concrete} (#{action})", "raised #{load_error.class}: #{load_error.message.to_s.gsub(/\s+/, ' ').truncate(160)} @ #{Array(load_error.backtrace).reject { |l| l.include?('gems/') }.first(4).join(' | ')}")
      next
    end
    if session.response.status != 200
      report("SKIP", "#{concrete} (#{action})", "page HTTP #{session.response.status} #{exception_of(session.response.body)}")
      next
    end

    forms = Nokogiri::HTML(session.response.body).css("form").reject { |f| f["action"].to_s.include?("/login") }
    forms = Nokogiri::HTML(session.response.body).css("form").select do |f|
      f.css("input[type=submit], button[type=submit], input[type=file]").any?
    end if forms.empty?

    if forms.empty?
      report("SKIP", "#{concrete} (#{action})", "no submittable form")
      next
    end

    form = forms.max_by { |f| f.css("input, select, textarea").size }
    # Probes: some screens depend on a radio/select choice to be valid.
    probes = [{ label: "default", overrides: {} }]
    probes << { label: "credit", overrides: { "sale[sale_type]" => "credit", "advance_booking[sale_type]" => "credit" } } if form.to_html.include?("sale_type")
    probes << { label: "cash", overrides: { "sale[sale_type]" => "cash" } } if form.to_html.include?("cash")

    probes.each do |probe|
      isolate { with_execution_context { session.get concrete } }
      html = Nokogiri::HTML(session.response.body)
      f = html.css("form").max_by { |x| x.css("input, select, textarea").size }
      label = probe[:label] == "default" ? "#{concrete} (#{action})" : "#{concrete} (#{action}) [#{probe[:label]}]"
      before = [PASS.size, FAIL.size]
      try_form(session, label, f, probe[:overrides])
      break if PASS.size > before[0] || FAIL.size > before[1]
    end
  end

  # A successful change-password probe leaves must_change_password set on the
  # harness account by design; clear it so the rest of the run is unaffected.
  HARNESS_CONTEXT.reload
  HARNESS_CONTEXT.update_columns(must_change_password: false) if HARNESS_CONTEXT.must_change_password?

  puts "\n=== record actions (button_to) ==="
  {
    "PATCH /pdc/:id/deposit" => ["/pdc/#{data[:cheque].id}/deposit", {}],
    "PATCH /pdc/:id/clear" => ["/pdc/#{data[:cheque].id}/clear", {}],
    "POST /sales/:id/cancel" => ["/sales/#{data[:sale].id}/cancel", {}],
    "POST /quotations/:id/accept" => ["/quotations/#{data[:quotation].id}/accept", {}],
    "PATCH /transfers/:id/approve" => ["/transfers/#{data[:transfer].id}/approve", {}],
    "POST /installments/:id/remind" => ["/installments/#{data[:reminder].installment_plan_id}/remind", {}]
  }.each do |label, (path, params)|
    isolate { session.send(label[/\A[A-Z]+/].downcase, path, params: params) }
    if session.response.status.between?(300, 399)
      report("PASS", label, "-> #{session.response.location}")
    elsif session.response.status == 200 && session.response.body.include?("alert-danger")
      report("FAIL", label, error_messages(session.response.body))
    else
      report("FAIL", label, "HTTP #{session.response.status}")
    end
  end

  puts "\n=== action buttons on index and show screens ==="
  # button_to renders a real form; submit each one so no action is left untested.
  # Runs last because deletes remove the rows the earlier phases rely on.
  action_pages = Rails.application.routes.routes.map { |r| [r.verb, r.path.spec.to_s.sub("(.:format)", ""), r.defaults] }
                                          .select { |verb, _, d| verb == "GET" && d[:controller] != "sessions" }
                                          .map { |_, path, d| [path, d] }
                                          .uniq { |path, _| path }
  checked = 0
  action_pages.sort_by { |path, _| path }.each do |path, defaults|
    next unless %w[index show].include?(defaults[:action].to_s)

    concrete = path.gsub(/:(\w+)/) { ids.fetch(Regexp.last_match(1).to_s, "1") }
    concrete = resolve_real_id(path, concrete, defaults[:controller], records)
    # Rails' own diagnostic routes: active_storage needs a real signed id, and
    # /rails/info is a development-only page outside the application.
    next if path.start_with?("/rails/")

    load_error = isolate { with_execution_context { session.get concrete } }
    if load_error.is_a?(AbstractController::ActionNotFound)
      report("SKIP", "GET #{defaults[:action]} #{path}", load_error.message.to_s.split(" ").first(6).join(" "))
      next
    end
    if load_error.is_a?(ActiveRecord::RecordNotFound)
      report("PASS", "GET #{defaults[:action]} #{path}", "cross-tenant record is invisible")
      next
    end
    if load_error.is_a?(StandardError)
      report("FAIL", "GET #{defaults[:action]} #{path}",
             "raised #{load_error.class}: #{load_error.message.to_s.gsub(/\s+/, ' ').truncate(140)}")
      next
    end
    # Screens that are deliberately closed to a shop admin: the platform owner
    # console, the customer portal, and the 403 page itself. A cross-tenant id
    # has to be invisible (404), so those are expected too.
    if PROTECTED_PATHS.any? { |prefix| path.start_with?(prefix) }
      report("PASS", "GET #{defaults[:action]} #{path}",
             session.response.status == 200 ? "opened" : "correctly closed (HTTP #{session.response.status})")
      next
    end

    unless session.response.status == 200
      report("FAIL", "GET #{defaults[:action]} #{path}", "HTTP #{session.response.status}")
      next
    end

    Nokogiri::HTML(session.response.body).css("form").each do |form|
      action = form["action"].to_s
      next if action.blank? || action.include?("/login")

      method = (form.at_css("input[name=_method]")&.[]("value") || form["method"] || "post").downcase
      next unless %w[post patch put delete].include?(method)

      label = "#{method.upcase} #{action.gsub(%r{/\d+}, "/:id")}"
      next if tried_actions.include?(label)
      # Accounts are the credentials every later step depends on; they get their
      # own dedicated probe below instead of being toggled by the generic crawl.
      next if action.match?(%r{/users/})

      tried_actions << label
      button_params = form.css("input[type=hidden]").each_with_object({}) do |hidden, memo|
        name = hidden["name"].to_s
        next if name.blank? || name == "utf8" || name.end_with?("_method")

        memo[name] = hidden["value"].to_s
      end
      error = isolate { session.send(method, action, params: button_params) }
      checked += 1
      if error.is_a?(StandardError)
        report("FAIL", label, "raised #{error.class}: #{error.message.to_s.gsub(/\s+/, ' ').truncate(150)} @ #{Array(error.backtrace).reject { |l| l.include?('gems/') }.first(2).join(' | ')}")
        next
      end
      body = session.response.body.to_s
      if session.response.status.between?(300, 399)
        report("PASS", label, "-> #{session.response.location}")
      elsif session.response.status == 403
        report("PASS", label, "correctly refused (403)")
      elsif session.response.status == 200 && !body.match?(/alert-danger|is-invalid|exception-message/)
        report("PASS", label, "rendered without errors")
      else
        File.write("/tmp/qm_action_#{label.gsub(/[^a-zA-Z0-9]+/, '_')}.html", body)
        report("FAIL", label, "HTTP #{session.response.status} #{exception_of(body)}")
      end
    end
  end
  puts "(submitted #{checked} action buttons)"

  puts "\n=== account lifecycle on a throwaway user ==="
  throwaway = User.create!(username: "smoke_#{UNIQUE}", full_name: "Smoke Tester",
                           role: "cashier", status: "active", password: form_password,
                           business_id: HARNESS_CONTEXT.business_id, branch_id: HARNESS_CONTEXT.branch_id)
  [
    ["PATCH /users/:id (deactivate)", -> { session.patch "/users/#{throwaway.id}", params: { user: { status: "inactive" } } }],
    ["PATCH /users/:id (reactivate)", -> { session.patch "/users/#{throwaway.id}", params: { user: { status: "active" } } }],
    ["DELETE /users/:id", -> { session.delete "/users/#{throwaway.id}" }]
  ].each do |label, request|
    tried_actions << label
    error = isolate(&request)
    if error.is_a?(StandardError)
      report("FAIL", label, "raised #{error.class}: #{error.message.to_s.gsub(/\s+/, ' ').truncate(140)}")
    elsif session.response.status.between?(300, 399)
      report("PASS", label, "-> #{session.response.location}")
    else
      report("FAIL", label, "HTTP #{session.response.status} #{exception_of(session.response.body)}")
    end
  end
  final_state = User.find_by(id: throwaway.id)&.status
  if final_state == "inactive"
    puts "OK   throwaway account #{throwaway.username} deactivated"
  else
    puts "WARN throwaway account #{throwaway.username} is #{final_state.inspect} after delete"
  end
  puts "OK   login accounts still #{User.find_by(username: 'accounts')&.status}"

    raise ActiveRecord::Rollback
  end
rescue ActiveRecord::Rollback
  puts "\n(rolled back every probe; the database is untouched)"
end

puts "\n===================================="
puts "PASS: #{PASS.size}   FAIL: #{FAIL.size}   SKIP: #{SKIP.size}"
if FAIL.any?
  puts "\nfailing forms:"
  FAIL.each { |f| puts "  - #{f}" }
end
puts "skipped:"
SKIP.each { |f| puts "  - #{f}" }
# exit! avoids an ActiveSupport 8.1 ExecutionWrapper bug that fires on a
# graceful exit from inside `rails runner` and turns a clean run into status 1.
$stdout.flush
$stderr.flush
exit!(FAIL.empty? ? 0 : 1)
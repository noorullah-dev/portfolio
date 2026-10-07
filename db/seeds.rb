# Seeds a usable multi-business install: one platform owner, one or more shops
# each with a branch, a location and staff for every role, the chart of accounts,
# payment modes, a catalogue and a little operational history.
#
#   bin/rails db:seed
#   SEED_SECOND_SHOP=1 bin/rails db:seed      # also create a second demo shop
#   SEED_VOLUME=0 bin/rails db:seed           # baseline data only, no bulk volume
#   SEED_SALES=400 SEED_CUSTOMERS=600 bin/rails db:seed   # tune the bulk volume
#
# See db/seeds/volume.rb for the bulk sections and their targets.
#
# Every tenant owned row is created inside the shop admin's Current context, so
# the records carry the right business_id/branch_id exactly like a real request.
require "securerandom"

def with_tenant(user)
  Current.set_from(user)
  yield
ensure
  Current.reset!
end

# --------------------------------------------------------------------------
# Platform owner
# --------------------------------------------------------------------------
puts "seeding platform owner..."

owner = User.find_or_initialize_by(username: ENV.fetch("OWNER_USERNAME", "owner"))
owner.assign_attributes(
  full_name: ENV.fetch("OWNER_NAME", "Platform Owner"),
  role: "owner",
  business: nil,
  branch: nil,
  password: ENV.fetch("OWNER_PASSWORD", "owner123"),
  status: "active",
  must_change_password: ENV["OWNER_PASSWORD"].nil?
)
owner.save!

# --------------------------------------------------------------------------
# Shops
# --------------------------------------------------------------------------
SHOPS = [
  {
    name: ENV.fetch("BUSINESS_NAME", "Tamoor Autos"),
    slug: ENV.fetch("BUSINESS_SLUG", "tamoor-autos"),
    phone: ENV.fetch("BUSINESS_PHONE", "0300-1234567"),
    email: ENV.fetch("BUSINESS_EMAIL", "info@tamoorautos.pk"),
    address: ENV.fetch("BUSINESS_ADDRESS", "Main Auto Market, Lahore"),
    admin_username: "admin",
    admin_password: ENV.fetch("ADMIN_PASSWORD", "admin123"),
    staff: {
      "manager" => ["Branch Manager", "manager123", "branch_manager"],
      "accounts" => ["Accounts Officer", "accounts123", "accountant"],
      "cashier" => ["Counter Cashier", "cashier123", "cashier"],
      "recovery" => ["Recovery Officer", "recovery123", "recovery_officer"]
    }
  }
]

if ENV["SEED_SECOND_SHOP"].present?
  SHOPS << SHOPS.first.merge(
    name: ENV.fetch("SECOND_BUSINESS_NAME", "Second Shop"),
    slug: ENV.fetch("SECOND_BUSINESS_SLUG", "second-shop"),
    phone: "0300-7654321",
    email: "info@secondshop.pk",
    address: "Auto Plaza, Karachi",
    admin_username: "shop2",
    admin_password: ENV.fetch("SECOND_ADMIN_PASSWORD", "shop2pass"),
    staff: {}
  )
end

def seed_shop(shop, owner)
  business = Business.find_or_initialize_by(slug: shop[:slug])
  business.assign_attributes(
    name: shop[:name],
    slug: shop[:slug],
    business_type: ENV.fetch("BUSINESS_TYPE", "3"),
    phone: shop[:phone],
    email: shop[:email],
    address: shop[:address],
    currency: ENV.fetch("BUSINESS_CURRENCY", "Rs."),
    footer_text: ENV.fetch("BUSINESS_FOOTER", "Thank you for your business!"),
    status: "active",
    plan: "standard",
    provisioned_by: owner
  )
  business.save!

  branch = Branch.find_or_initialize_by(business: business, name: "Main Branch")
  branch.assign_attributes(code: "MAIN", branch_type: "main", status: "active", is_default: true)
  branch.save!

  annex = Branch.find_or_initialize_by(business: business, name: "#{shop[:name]} Annex")
  annex.assign_attributes(code: "ANNEX", branch_type: "sub", status: "active")
  annex.save!

  location = Location.find_or_initialize_by(business: business, name: "All Locations")
  location.assign_attributes(city: "Unassigned", status: "active")
  location.save!

  depot = Location.find_or_initialize_by(business: business, name: "Workshop")
  depot.assign_attributes(city: "Lahore", status: "active")
  depot.save!

  admin = User.find_or_initialize_by(username: shop[:admin_username])
  admin.assign_attributes(
    full_name: "#{shop[:name]} Administrator",
    role: "shop_admin",
    business: business,
    branch: branch,
    password: shop[:admin_password],
    status: "active",
    must_change_password: false,
    provisioned_by: owner
  )
  admin.save!

  shop[:staff].each do |username, (full_name, password, role)|
    staff = User.find_or_initialize_by(username: username)
    staff.assign_attributes(
      full_name: full_name,
      role: role,
      business: business,
      branch: branch,
      password: password,
      status: "active",
      must_change_password: false,
      provisioned_by: owner
    )
    staff.save!
    next unless role == "recovery_officer"

    UserLocation.find_or_create_by!(user: staff, location: location)
  end

  [business, admin]
end

puts "seeding shops..."

seeded = SHOPS.map { |shop| seed_shop(shop, owner) }
seeded.each { |business, _admin| puts "  #{business.name} (#{business.slug})" }

# --------------------------------------------------------------------------
# Reference data - per shop, created inside the shop admin's context
# --------------------------------------------------------------------------
ACCOUNTS = [
  ["1000", "Cash in Hand", "asset", true],
  ["1010", "Bank Accounts", "asset", true],
  ["1100", "Accounts Receivable (Customers)", "asset", false],
  ["1200", "Vehicles / Stock in Trade", "asset", false],
  ["1300", "Advances to Suppliers", "asset", false],
  ["2100", "Accounts Payable (Suppliers)", "liability", false],
  ["3100", "Vehicle Sales Revenue", "income", false],
  ["3200", "Advance Booking Revenue", "income", false],
  ["4100", "Cost of Vehicles Sold", "expense", false],
  ["5100", "Office Expenses", "expense", false],
  ["5110", "Rent Expense", "expense", false],
  ["5120", "Utilities Expense", "expense", false],
  ["5130", "Salaries and Wages", "expense", false],
  ["5140", "Advertisement Expense", "expense", false],
  ["5150", "Vehicle Service and Repair", "expense", false],
  ["5160", "Fuel Expense", "expense", false],
  ["5170", "Bank Charges", "expense", false],
  ["5180", "Miscellaneous Expense", "expense", false],
  ["6100", "Agent Commission Expense", "expense", false],
  ["7100", "Owner Drawings", "equity", false]
].freeze

BRANDS = ["Toyota", "Honda", "Suzuki", "Nissan", "Mitsubishi", "Kia", "Hyundai", "Changan",
          "Prince", "Daihatsu", "Master Changan", "FAW", "MG", "Proton"].freeze

PRODUCT_CATEGORIES = {
  "vehicle" => %w[Corolla Camry Fortuner Hilux Aqua Vitz City Civic City ID3 HRV Fit Wagon City
                  Bolero Revo Cultus Wagon R Alto VXL Mehran City Captiva Pajero Sport
                  Starex Grace Juke Kicks Qashqai Tiida Sunny Grand T10 Urban Cruiser],
  "electronics" => ["Speaker System", "Reverse Camera", "Head Unit", "Android Player"],
  "general" => ["Number Plates", "Tool Kit", "Floor Mats", "Seat Covers"]
}.freeze

EXPENSE_CATEGORIES = ["Office Supplies", "Fuel", "Maintenance", "Utilities", "Salaries",
                      "Advertisement", "Rent", "Insurance", "Taxes & Fees",
                      "Miscellaneous"].freeze

PAYMENT_MODES = ["Cash", "Bank", "JazzCash", "EasyPaisa", "Cheque", "Online"].freeze

SUPPLIERS = ["Indus Motors", "City Cars", "Auto Link Traders", "Pak Wheels", "Sun Auto"].freeze

AGENTS = { "Imran Khan" => "percent:3", "Bilal Ahmed" => "percent:2",
           "Kamran Shah" => "fixed:25000" }.freeze

DEMO_CATALOGUE = [
  ["Honda", "City", "vehicle", "1.5", %w[Automatic Manual], 62_000],
  ["Toyota", "Corolla", "vehicle", "1.8", %w[Automatic Manual], 68_000],
  ["Suzuki", "GS 150", "vehicle", "150cc", ["Standard"], 8_500],
  ["Yamaha", "YZF R15", "vehicle", "150cc", %w[Standard V2], 9_200],
  ["Honda", "CG 125", "vehicle", "125cc", ["Standard"], 4_800]
].freeze

DEMO_CUSTOMERS = [
  ["Ali Raza", "0300-1234567"], ["Bilal Khan", "0311-7654321"],
  ["Usman Tariq", "0322-3456789"], ["Hassan Nawaz", "0333-4567890"],
  ["Zain Abbas", "0345-5678901"]
].freeze

def seed_reference_data
  ACCOUNTS.each do |code, name, type, is_cash|
    account = ChartOfAccount.find_or_initialize_by(business_id: Current.business_id, code: code)
    account.update!(name: name, account_type: type, is_cash_account: is_cash, status: "active")
  end

  PAYMENT_MODES.each_with_index do |name, index|
    mode = PaymentMode.shop.find_or_initialize_by(name: name)
    mode.update!(is_cash: name == "Cash", status: "active", sort_order: index)
  end

  EXPENSE_CATEGORIES.each do |name|
    ExpenseCategory.shop.find_or_create_by!(name: name) { |category| category.status = "active" }
  end

  BRANDS.each { |name| Brand.shop.find_or_create_by!(name: name) { |brand| brand.status = "active" } }

  PRODUCT_CATEGORIES.each do |type, names|
    names.each do |name|
      category = Category.shop.find_or_initialize_by(name: name)
      category.category_type = type
      category.save!
    end
  end

  SUPPLIERS.each { |name| Supplier.shop.find_or_create_by!(name: name) }

  AGENTS.each do |name, rule|
    type, amount = rule.split(":")
    Agent.shop.find_or_create_by!(name: name) do |agent|
      agent.phone = "0300#{rand(1_000_000..9_999_999)}"
      agent.commission_type = type
      agent.commission_amount = amount
    end
  end
end

def seed_catalogue
  DEMO_CATALOGUE.each do |brand_name, model, category_name, spec, colours, price|
    brand = Brand.shop.find_or_create_by!(name: brand_name) { |record| record.status = "active" }
    category = Category.shop.find_or_create_by!(name: category_name) do |record|
      record.category_type = category_name
      record.status = "active"
    end
    product = Product.find_or_create_by!(brand: brand, name: model) do |record|
      record.category = category
      record.status = "active"
    end
    colours.each do |colour|
      Variant.find_or_create_by!(product: product, value: "#{spec} #{colour}") do |record|
        record.attribute_name = "Specification"
        record.purchase_price = price
        record.sale_price = (price * 1.15).round
        record.status = "active"
      end
    end
  end
end

def seed_demo_activity(admin)
  return if Sale.shop.any?

  # Vehicle identity numbers are unique across the platform, so they carry the
  # shop slug to keep two demo shops from colliding.
  tag = Current.business.slug.to_s.first(3).upcase

  account = ->(code) { ChartOfAccount.shop.find_by!(code: code) }

  product = Product.shop.where(status: "active").first
  variant = product&.variants&.order(:id)&.first
  agent = Agent.shop.order(:id).first

  # Idempotent so a previously interrupted seed run converges instead of
  # colliding with the rows it already wrote.
  stock = 6.times.map do |i|
    StockUnit.find_or_create_by!(engine_no: "DEMO-#{tag}-ENG-#{1000 + i}") do |unit|
      unit.chassis_no = "DEMO-#{tag}-CHS-#{2000 + i}"
      unit.product = product
      unit.variant = variant
      unit.cost_price = 4_000_000
      unit.date_added = Date.current - rand(20..120).days
      unit.status = "available"
    end
  end

  customers = DEMO_CUSTOMERS.each_with_index.map do |(name, phone), i|
    Customer.find_or_create_by!(account_no: format("CUS-%s-%d-%04d", tag, Date.current.year, i + 1)) do |customer|
      customer.name = name
      customer.phone = phone
      customer.address = "#{20 + i} Mall Road, Karachi"
      customer.status = "active"
    end
  end

  customers.each_with_index.map do |customer, i|
    sale = Sale.create!(
      customer: customer,
      sale_date: Date.current - rand(10..90).days,
      sale_type: "credit",
      stock_unit: stock[i],
      agent: agent,
      total_amount: 4_500_000,
      down_payment: 500_000,
      months: 12,
      created_by: admin
    )
    next unless i < 3

    InstallmentPayment.create!(
      sale: sale,
      installment_plan: sale.installment_plans.order(:installment_no).first,
      amount: 150_000,
      payment_date: Date.current - rand(5..40).days,
      payment_mode: PaymentMode.first,
      reference: "DEMO-#{sale.sale_no}",
      created_by: admin
    )
  end

  3.times do |i|
    AdvanceBooking.create!(
      customer: Customer.shop.order(:id)[i],
      booking_date: Date.current + (i + 1).weeks,
      total_amount: 4_500_000,
      advance_amount: 250_000,
      sale_type: "credit",
      months: 12,
      status: "confirmed",
      remarks: "Demo booking #{i + 1}",
      created_by: admin
    )
  end

  JournalVoucher.create!(
    voucher_date: Date.current - 5.days,
    description: "Demo office rent payment",
    status: "draft",
    posted_by: admin
  ).tap do |voucher|
    voucher.lines.create!(account: account.call("5110"), debit: 50_000, remarks: "Rent")
    voucher.lines.create!(account: account.call("1010"), credit: 50_000, remarks: "Bank")
    voucher.post!(user: admin)
  end

  Expense.create!(
    expense_date: Date.current - 3.days,
    category: ExpenseCategory.first,
    description: "Demo stationery purchase",
    amount: 12_000,
    account: account.call("1010"),
    payment_mode: PaymentMode.first,
    added_by: admin
  )

  Quotation.create!(
    customer: Customer.shop.order(:id).last,
    product: product,
    variant: variant,
    quotation_date: Date.current,
    months: 12,
    sale_price: 4_650_000,
    down_payment: 650_000,
    status: "draft",
    created_by: admin
  )

  # Give the demo stock units real identity numbers so the stock list reads like
  # the captured design.
  StockUnit.shop.where("engine_no LIKE ?", "DEMO-#{tag}-%").order(:id).each_with_index do |unit, i|
    vehicle = DEMO_CATALOGUE[i % DEMO_CATALOGUE.length]
    brand = Brand.shop.find_by(name: vehicle[0])
    product = Product.shop.find_by(brand: brand, name: vehicle[1])
    unit.update!(
      product: product,
      variant: product.variants.order(:id).first,
      challan_no: format("CH-%d-%04d", Date.current.year, i + 1),
      reg_no: format("K%03d-ABC", 1000 + i),
      biometric: i.even?,
      serial_no: "SN#{format('%06d', i + 1)}",
      warranty_months: [12, 24, 36][i % 3],
      colour: ["White", "Black", "Silver", "Red", "Blue"][i % 5],
      date_added: Date.current - (20 + (i * 17)).days
    )
  end
end

seeded.each do |business, admin|
  summary = with_tenant(admin) do
    seed_reference_data
    seed_catalogue
    seed_demo_activity(admin)
    "#{ChartOfAccount.shop.count} accounts, #{Customer.shop.count} customers, " \
      "#{Sale.shop.count} sales, #{Product.shop.count} products"
  end
  puts "  #{business.name}: #{summary}"
end

if ENV["SEED_VOLUME"] != "0"
  require_relative "seeds/volume"

  puts "\nseeding bulk volume data..."
  seeded.each do |business, admin|
    summary = with_tenant(admin) { seed_volume(business, admin, owner) }
    puts "  #{business.name}: #{summary.presence || 'already at target'}"
  end
end

puts "\nplatform owner: #{owner.username} / #{ENV.fetch('OWNER_PASSWORD', 'owner123')}"
seeded.each do |_business, admin|
  puts "shop admin:     #{admin.username} / #{admin.reload.username == 'admin' ? ENV.fetch('ADMIN_PASSWORD', 'admin123') : ENV.fetch('SECOND_ADMIN_PASSWORD', 'shop2pass')}"
end
puts "staff logins:   manager / accounts / cashier / recovery (#{ENV.fetch('BUSINESS_NAME', 'Tamoor Autos')} only)"
puts "done. #{Business.count} shops, #{User.count} users, #{Product.count} products."

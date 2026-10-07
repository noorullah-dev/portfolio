require "test_helper"

# The hand written index, dashboard and report queries must never mix shops.
# Everything is asserted from the rendered page so the test needs no extra gems.
class CrossTenantScreensTest < ActionDispatch::IntegrationTest
  # Each shop owns its own chart, so posting never crosses businesses.
  SYSTEM_ACCOUNTS = {
    "1000" => ["Cash in Hand", "asset"],
    "1010" => ["Bank Accounts", "asset"],
    "1100" => ["Accounts Receivable", "asset"],
    "1200" => ["Stock in Trade", "asset"],
    "2100" => ["Accounts Payable", "liability"],
    "3100" => ["Sales Revenue", "income"],
    "4100" => ["Cost of Vehicles Sold", "expense"],
    "5100" => ["Office Expenses", "expense"]
  }.freeze

  setup do
    @alpha = create_business(name: "Alpha Motors")
    @beta = create_business(name: "Beta Motors")
    [@alpha, @beta].each { |business| chart_for(business) }

    @alpha_admin = create_user(business: @alpha, username: "alpha-admin")
    @beta_admin = create_user(business: @beta, username: "beta-admin")

    as(@alpha_admin) { @alpha_sale = create_sale_for(@alpha, "Alpha Customer", 9_000) }
    as(@beta_admin) { @beta_sale = create_sale_for(@beta, "Beta Customer", 440) }
  end

  def chart_for(business)
    SYSTEM_ACCOUNTS.each do |code, (name, type)|
      ChartOfAccount.create!(business: business, code: code, name: name, account_type: type)
    end
  end

  def brand_for(business)
    Brand.find_or_create_by!(business_id: business.id, name: "Brand #{business.id}") { |b| b.status = "active" }
  end

  def category_for(business)
    Category.find_or_create_by!(business_id: business.id, name: "Category #{business.id}") do |category|
      category.category_type = "vehicle"
      category.status = "active"
    end
  end

  def ledger_for(record)
    LedgerEntry.where(source_type: record.class.name, source_id: record.id)
  end

  def create_sale_for(business, customer_name, total)
    customer = Customer.create!(business: business, name: customer_name,
                                account_no: "ACC-#{business.id}", status: "active")
    product = Product.create!(brand: brand_for(business), category: category_for(business),
                              name: "Model #{business.id}", status: "active")
    unit = StockUnit.create!(product: product, engine_no: "ENG-#{business.id}", cost_price: 100,
                             date_added: Date.current, status: "available")
    Sale.create!(customer: customer, sale_date: Date.current, sale_type: "cash", stock_unit: unit,
                 total_amount: total, cost_amount: 50)
  end

  def assert_shop_only(body, own_marker, foreign_marker, screen)
    assert_includes body, own_marker, "#{screen} should show the signed in shop's data"
    refute_includes body, foreign_marker, "#{screen} leaked another shop's data"
  end

  test "dashboard only counts the signed in shop" do
    sign_in_as(@alpha_admin)
    get dashboard_path
    assert_response :success
    assert_shop_only response.body, "Alpha Customer", "Beta Customer", "dashboard"

    sign_in_as(@beta_admin)
    get dashboard_path
    assert_response :success
    assert_shop_only response.body, "Beta Customer", "Alpha Customer", "dashboard"
  end

  test "reports only total the signed in shop" do
    sign_in_as(@alpha_admin)
    get reports_path
    assert_response :success
    assert_shop_only response.body, "9,000.00", "440.00", "reports"

    sign_in_as(@beta_admin)
    get reports_path
    assert_response :success
    assert_shop_only response.body, "440.00", "9,000.00", "reports"
  end

  test "index screens never list another shop's rows" do
    sign_in_as(@alpha_admin)

    [sales_path, stock_units_path, customers_path, credit_recoveries_path, account_closures_path,
     post_dated_cheques_path, agent_commissions_path, advance_bookings_path, quotations_path,
     purchases_path, expenses_path, account_transfers_path, cash_book_path,
     journal_vouchers_path, receipt_vouchers_path, payment_vouchers_path, roznamcha_path,
     short_payments_path, registration_trackings_path, vehicle_documents_path, agents_path,
     suppliers_path, brands_path, categories_path, variants_path, chart_of_accounts_path].each do |path|
      get path
      assert_response :success, "#{path} returned #{response.status}"
      assert_shop_only response.body, "Alpha", "Beta", path
    end
  end

  test "system accounts resolve inside the signed in shop" do
    as(@alpha_admin) do
      assert_equal @alpha.id, Business.account("5100").business_id
      expense = Expense.create!(expense_date: Date.current, description: "Alpha rent", amount: 25,
                                added_by: @alpha_admin)
      assert ledger_for(expense).all? { |entry| entry.account.business_id == @alpha.id },
             "an expense posted in Alpha must not touch Beta's chart of accounts"
      assert_equal [@alpha.id], @alpha_sale.ledger_entries.map { |entry| entry.account.business_id }.uniq
    end

    as(@beta_admin) do
      assert_equal @beta.id, Business.account("5100").business_id
      expense = Expense.create!(expense_date: Date.current, description: "Beta rent", amount: 25,
                                added_by: @beta_admin)
      assert ledger_for(expense).all? { |entry| entry.account.business_id == @beta.id },
             "an expense posted in Beta must not touch Alpha's chart of accounts"
      assert_equal [@beta.id], @beta_sale.ledger_entries.map { |e| e.account.business_id }.uniq
    end
  end

  test "reference data dropdowns only offer the signed in shop" do
    sign_in_as(@alpha_admin)
    get new_product_path
    assert_response :success
    assert_select "select[name='product[brand_id]'] option", text: /Brand #{@alpha.id}/
    assert_select "select[name='product[brand_id]'] option", text: /Brand #{@beta.id}/, count: 0
    assert_select "select[name='product[category_id]'] option", text: /Category #{@alpha.id}/
    assert_select "select[name='product[category_id]'] option", text: /Category #{@beta.id}/, count: 0
  end

  test "the platform owner still reads across shops" do
    sign_in_as(create_user(role: "owner"))
    get reports_path
    assert_response :success
    assert_includes response.body, "9,440.00"

    get reports_path(report: "customers")
    assert_response :success
    assert_includes response.body, "Alpha Customer"
    assert_includes response.body, "Beta Customer"
  end
end

require "test_helper"

class PermissionControlsTest < ActionDispatch::IntegrationTest
  setup do
    @business = create_business
    @branch = create_branch(business: @business)
    @admin = create_user(business: @business, branch: @branch)
    @cashier = create_user(business: @business, branch: @branch, role: "cashier")
    @accountant = create_user(business: @business, branch: @branch, role: "accountant")
    @officer = create_user(business: @business, branch: @branch, role: "recovery_officer")
    @owner = create_user(role: "owner")
    as(@admin) do
      {
        "1000" => ["Cash", "asset"], "1010" => ["Bank", "asset"],
        "1100" => ["Receivables", "asset"], "1200" => ["Stock", "asset"],
        "2100" => ["Payables", "liability"], "3100" => ["Sales", "income"],
        "4100" => ["Cost of sales", "expense"], "5100" => ["Expenses", "expense"]
      }.each do |code, (name, type)|
        ChartOfAccount.create!(code: code, name: name, account_type: type)
      end
      @customer = Customer.create!(name: "Visible Customer")
      @supplier = Supplier.create!(name: "Visible Supplier", status: "active")
      @sale = Sale.create!(customer: @customer, branch: @branch, sale_date: Date.current, sale_type: "credit",
                           total_amount: 100, months: 2)
      @booking = AdvanceBooking.create!(customer: @customer, branch: @branch, booking_date: Date.current,
                                        total_amount: 100, status: "confirmed")
    end
  end

  test "cashier sees allowed customer actions but no delete or management links" do
    sign_in_as @cashier
    get customers_path
    assert_response :success
    assert_select "a[href='#{new_customer_path}']"
    assert_select "a[href='#{edit_customer_path(@customer)}']"
    assert_select "form[action='#{customer_path(@customer)}']", count: 0
    assert_select "a[href='#{users_path}']", count: 0
    assert_select "a[href='#{business_settings_path}']", count: 0
    assert_select "a[href='#{new_purchase_path}']", count: 0
    assert_select "a[href='#{purchases_path}']"
    assert_select "a[href='#{owner_businesses_path}']", count: 0
  end

  test "accountant can read customers without create edit or delete controls" do
    sign_in_as @accountant
    get customers_path
    assert_response :success
    assert_select "a[href='#{new_customer_path}']", count: 0
    assert_select "a[href='#{edit_customer_path(@customer)}']", count: 0
    assert_select "form[action='#{customer_path(@customer)}']", count: 0
    assert_select "a[href='#{customer_path(@customer)}']"
    get customer_path(@customer)
    assert_response :success
    assert_select "a[href^='#{new_sale_path}']", count: 0
    assert_select "a[href='#{edit_customer_path(@customer)}']", count: 0
  end

  test "recovery dashboard omits new sales and inaccessible stock navigation" do
    sign_in_as @officer
    get root_path
    assert_response :success
    assert_select "a[href='#{new_sale_path}']", count: 0
    assert_select "a[href='#{stock_units_path}']", count: 0
    assert_select "a[href='#{products_path}']", count: 0
    assert_select "a[href='#{reports_path}']", count: 0
    assert_select "a[href='#{installment_collections_path}']"
    get sales_path
    assert_response :success
    assert_select "a[href='#{new_sale_path}']", count: 0
  end

  test "read-only sale actions keep collection while hiding editing and document writes" do
    sign_in_as @accountant
    get sale_path(@sale)
    assert_response :success
    assert_select "a[href='#{new_sale_payment_path(@sale)}']"
    assert_select "a[href='#{edit_sale_path(@sale)}']", count: 0
    assert_select "form[action='#{cancel_sale_path(@sale)}']", count: 0
    assert_select "form[action='#{sale_vehicle_documents_path(@sale)}']", count: 0
  end

  test "cashier cannot pay a booking while accountant can" do
    sign_in_as @cashier
    get advance_booking_path(@booking)
    assert_response :success
    assert_select "form[action='#{advance_booking_advance_booking_payments_path(@booking)}']", count: 0
    sign_in_as @accountant
    get advance_booking_path(@booking)
    assert_response :success
    assert_select "form[action='#{advance_booking_advance_booking_payments_path(@booking)}']"
  end

  test "supplier ledger is hidden for cashier and available for accountant" do
    sign_in_as @cashier
    get suppliers_path
    assert_response :success
    assert_select "a[href='#{ledger_supplier_path(@supplier)}']", count: 0
    assert_select "a[href='#{new_supplier_path}']", count: 0
    get ledger_supplier_path(@supplier)
    assert_redirected_to access_denied_path
    sign_in_as @accountant
    get suppliers_path
    assert_response :success
    assert_select "a[href='#{ledger_supplier_path(@supplier)}']"
    # The ledger itself must render for an accountant, purchase and payment rows
    # included (the payment loop used to reference a missing association).
    as(@admin) do
      purchase = Purchase.create!(supplier: @supplier, branch: @branch, purchase_date: Date.current,
                                  status: "completed", total_amount: 500)
      PurchasePayment.create!(purchase: purchase, payment_date: Date.current, amount: 200)
    end
    get ledger_supplier_path(@supplier)
    assert_response :success
    assert_select "table tbody tr", minimum: 2
  end

  test "owner sees business records without shop mutation controls" do
    sign_in_as @owner
    get customers_path
    assert_response :success
    assert_select "a[href='#{customer_path(@customer)}']"
    assert_select "a[href='#{new_customer_path}']", count: 0
    assert_select "a[href='#{edit_customer_path(@customer)}']", count: 0
    assert_select "form[action='#{customer_path(@customer)}']", count: 0
    assert_select "a[href='#{owner_businesses_path}']"
    get owner_businesses_path
    assert_response :success
    assert_select "a[href='#{new_owner_business_path}']"
    get sale_path(@sale)
    assert_response :success
    assert_select "a[href='#{new_sale_payment_path(@sale)}']", count: 0
    assert_select "a[href='#{edit_sale_path(@sale)}']", count: 0
    assert_select "form[action='#{cancel_sale_path(@sale)}']", count: 0
    assert_select "form[action='#{sale_vehicle_documents_path(@sale)}']", count: 0
  end

  test "hidden financial and management actions also reject direct requests" do
    sign_in_as @cashier
    post purchase_purchase_payments_path(0), params: { amount: 10 }
    assert_redirected_to access_denied_path
    post advance_booking_advance_booking_payments_path(@booking), params: { amount: 10 }
    assert_redirected_to access_denied_path
    post credit_recoveries_path, params: { credit_recovery: { amount: 10 } }
    assert_redirected_to access_denied_path
    post installment_reminder_path(0)
    assert_redirected_to access_denied_path
    post agent_commissions_path
    assert_redirected_to access_denied_path
    get edit_stock_unit_path(0)
    assert_redirected_to access_denied_path
    sign_in_as @officer
    get stock_unit_path(0)
    assert_redirected_to access_denied_path
    sign_in_as @accountant
    post sale_vehicle_documents_path(@sale)
    assert_redirected_to access_denied_path
    patch registration_tracking_path(0)
    assert_redirected_to access_denied_path
  end

  test "shop admin retains create edit delete and embedded payment controls" do
    sign_in_as @admin
    get customers_path
    assert_response :success
    assert_select "a[href='#{new_customer_path}']"
    assert_select "a[href='#{edit_customer_path(@customer)}']"
    assert_select "form[action='#{customer_path(@customer)}']"
    get sale_path(@sale)
    assert_response :success
    assert_select "a[href='#{edit_sale_path(@sale)}']"
    assert_select "form[action='#{cancel_sale_path(@sale)}']"
    assert_select "form[action='#{sale_vehicle_documents_path(@sale)}']"
    get new_customer_path
    assert_response :success
    assert_select "form[action='#{customers_path}']"
  end
end

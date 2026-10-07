require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @business = create_business(name: "Alpha Motors")
    @branch = create_branch(business: @business)
    @other_shop = create_business(name: "Beta Motors")
    @other_branch = create_branch(business: @other_shop, name: "Beta Main")
    @admin = create_user(business: @business, role: "shop_admin", branch: @branch, username: "alphaadmin")
    @manager = create_user(business: @business, role: "branch_manager", branch: @branch, username: "alphamgr")
    @cashier = create_user(business: @business, role: "cashier", branch: @branch, username: "alphacash")
    @accountant = create_user(business: @business, role: "accountant", branch: @branch, username: "alphaacct")
    @officer = create_user(business: @business, role: "recovery_officer", branch: @branch, username: "alphaoff")
    @owner = create_user(role: "owner", username: "theowner")
  end

  test "guests are sent to the sign in screen" do
    get root_path
    assert_redirected_to login_path

    get sales_path
    assert_redirected_to login_path
  end

  test "sign in screen renders for a url-only form" do
    # The sign-in form is posted to a path, so the permission-aware form helper is
    # called without a model. Rails rejects an explicitly nil model, which used to
    # turn this page into a 500 for signed-out visitors.
    assert_response :success, get(login_path)

    post login_path, params: { username: "ghost", password: "wrong" }
    assert_match(/invalid/i, response.body)
  end

  test "shop admin reaches the business screens" do
    sign_in_as @admin
    assert_response :success, get(customers_path)
    assert_response :success, get(users_path)
    assert_response :success, get(business_settings_path)
    assert_response :success, get(branches_path)
    assert_response :success, get(locations_path)
  end

  test "cashier may not open management screens" do
    sign_in_as @cashier
    assert_response :success, get(sales_path)
    # every refusal is recorded as well
    assert_difference -> { AuditLog.count } do
      get users_path
    end
    assert_redirected_to access_denied_path
    assert_redirected_to access_denied_path
    get business_settings_path
    assert_redirected_to access_denied_path
    get products_path
    assert_redirected_to access_denied_path
  end

  test "accountant is refused purchasing and product management" do
    sign_in_as @accountant
    assert_response :success, get(reports_path)
    get products_path
    assert_redirected_to access_denied_path
    get purchases_path
    assert_response :success
  end

  test "recovery officer only reaches recovery screens" do
    sign_in_as @officer
    assert_response :success, get(credit_recoveries_path)
    assert_response :success, get(installment_collections_path)
    %w[/products /reports /expenses].each do |path|
      get path
      assert_redirected_to access_denied_path
    end
  end

  test "branch manager cannot reach the platform owner console" do
    sign_in_as @manager
    assert_response :redirect, get(owner_businesses_path)
    follow_redirect!
    assert_response :forbidden
  end

  test "platform owner needs an open shop before writing, then has every permission" do
    sign_in_as @owner
    get sales_path
    assert_response :success

    # No shop open yet: a write is sent to the owner console to pick one.
    post sales_path, params: { sale: { party_name: "Injected" } }
    assert_redirected_to owner_businesses_path
    follow_redirect!
    assert_match(/Open a shop/i, response.body)

    # Opening a shop gives the owner the same reach as the shop's own staff.
    assert_difference -> { Customer.count } do
      post open_owner_business_path(@business)
      follow_redirect!
      post customers_path, params: { customer: { name: "Owner Customer", phone: "03001112222" } }
    end
    assert_redirected_to customers_path
    assert_equal @business.id, Customer.find_by(name: "Owner Customer").business_id
    assert Customer.find_by(name: "Owner Customer").persisted?
  end

  test "owner administration screens work once a shop is open" do
    sign_in_as @owner
    get users_path
    assert_redirected_to owner_businesses_path
    get new_branch_path
    assert_redirected_to owner_businesses_path
    follow_redirect!
    assert_response :success

    post open_owner_business_path(@business)
    assert_response :redirect

    get users_path
    assert_response :success
    get new_branch_path
    assert_response :success
    get new_location_path
    assert_response :success
  end

  test "platform owner may still run the owner console" do
    sign_in_as @owner
    get owner_businesses_path
    assert_response :success
    get new_owner_business_path
    assert_response :success
  end

  test "a shop admin may not promote anybody to platform owner" do
    sign_in_as @admin
    get edit_user_path(@admin)
    assert_response :success

    patch user_path(@admin), params: { user: { role: "owner", full_name: @admin.full_name } }
    assert_redirected_to users_path
    assert_equal "shop_admin", @admin.reload.role
  end

  test "one shop's records are invisible to another shop" do
    beta_customer = Customer.create!(business: @other_shop, name: "Beta Buyer", phone: "03001230003")
    sign_in_as @admin
    get customer_path(beta_customer)
    assert_response :not_found
  end

  test "a forged tenant in the form cannot place a row in another shop" do
    sign_in_as @admin
    post customers_path, params: { customer: { name: "Forged", phone: "03001239999",
                                                business_id: @other_shop.id } }

    created = Customer.find_by(name: "Forged")
    assert_not_nil created
    assert_equal @business.id, created.business_id, "the signed-in shop must win"
    assert_equal 0, Customer.where(business_id: @other_shop.id, name: "Forged").count
  end

  test "customer portal login cannot open the staff application" do
    customer = Customer.create!(business: @business, name: "Portal Buyer", phone: "03001235555")
    portal = create_user(role: "customer", customer: customer, username: "portaluser")

    sign_in_as portal
    get customer_portal_path
    assert_response :success
    assert_match(/Portal/i, response.body)

    get sales_path
    assert_redirected_to customer_portal_path
  end

  test "staff logins are kept out of the customer portal" do
    sign_in_as @admin
    get customer_portal_path
    assert_redirected_to root_path
  end

  test "a login with a temporary password is forced to change it first" do
    temp = create_user(business: @business, role: "cashier", branch: @branch, username: "tempuser")
    temp.update!(must_change_password: true)

    post login_path, params: { username: temp.username, password: "Passw0rd!123" }
    assert_response :redirect
    get root_path
    assert_redirected_to change_password_path
    follow_redirect!
    assert_response :success
  end

  test "changing the password opens the application again" do
    temp = create_user(business: @business, role: "cashier", branch: @branch, username: "tempuser2")
    temp.update!(must_change_password: true)
    post login_path, params: { username: temp.username, password: "Passw0rd!123" }
    follow_redirect!

    patch change_password_path, params: { current_password: "Passw0rd!123",
                                          password: "N3wPassw0rd!", password_confirmation: "N3wPassw0rd!" }
    assert_response :redirect
    get sales_path
    assert_response :success
  end

  test "wrong credentials are refused and audited" do
    assert_no_difference -> { AuditLog.count } do
      post login_path, params: { username: @cashier.username, password: "nope" }
    end
    assert_response :unprocessable_entity
  end

  test "an audit trail is written for privileged actions" do
    sign_in_as @admin
    assert_difference -> { AuditLog.count } do
      post customers_path, params: { customer: { name: "Audited Buyer", phone: "03001237777" } }
    end

    entry = AuditLog.where(user_id: @admin.id, action: "customers.create").order(:id).last
    assert_not_nil entry, "the create must be audited"
    assert_includes entry.summary, "Audited Buyer"
    assert_equal "Customer", entry.record_type
    assert_equal @business.id, entry.business_id
  end
end

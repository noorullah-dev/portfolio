require "test_helper"

class CustomerPortalTest < ActionDispatch::IntegrationTest
  setup do
    @business = create_business(name: "Alpha Motors")
    @branch = create_branch(business: @business)
    @location = create_location(business: @business, name: "Workshop")
    @customer = Customer.create!(business: @business, name: "Portal Buyer", phone: "03001234567",
                                location: @location)
    @portal = create_user(role: "customer", customer: @customer, username: "portalbuyer")
    @admin = create_user(business: @business, role: "shop_admin", branch: @branch, username: "portaladmin")
    @other_customer = Customer.create!(business: @business, name: "Somebody Else", phone: "03007654321")
  end

  test "a portal login sees its own account" do
    sign_in_as @portal

    get customer_portal_path
    assert_response :success
    assert_match @customer.name, response.body
    assert_no_match(/Somebody Else/, response.body)
  end

  test "the statement lists only this customer's sales" do
    sign_in_as @portal
    get customer_portal_statement_path
    assert_response :success
    assert_match(/Statement/i, response.body)
    assert_no_match(/Somebody Else/, response.body)
  end

  test "portal data is scoped to the customer even without a tenant context" do
    as(@portal) do
      assert_nil Current.business
      # a tenant scope without a business would be empty, so the controller has
      # to reach the data through the customer's own associations
      assert_empty @customer.sales
      assert_empty InstallmentPlan.shop
    end
  end

  test "staff cannot use the portal and the portal cannot use the staff app" do
    sign_in_as @admin
    get customer_portal_path
    assert_redirected_to root_path

    delete logout_path
    sign_in_as @portal
    get users_path
    assert_redirected_to customer_portal_path
    get business_settings_path
    assert_redirected_to customer_portal_path
  end

  test "a portal login without a customer account is refused" do
    orphan = User.new(full_name: "Orphan", username: "orphanportal", password: "Passw0rd!123", role: "customer")
    orphan.save!(validate: false)

    post login_path, params: { username: "orphanportal", password: "Passw0rd!123" }
    get customer_portal_path
    # no customer account behind the login, so the portal bounces it out
    assert_redirected_to login_path
  end
end

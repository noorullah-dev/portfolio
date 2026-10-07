require "test_helper"

class BranchManagementTest < ActionDispatch::IntegrationTest
  setup do
    @business = create_business
    @main = create_branch(business: @business, is_default: true)
    @annex = create_branch(business: @business, name: "Annex", branch_type: "sub")
    @other_business = create_business(name: "Other Shop")
    @foreign = create_branch(business: @other_business, name: "Foreign Branch")
    @admin = create_user(business: @business, branch: @main)
    @cashier = create_user(business: @business, branch: @annex, role: "cashier")
    @manager = create_user(business: @business, branch: @annex, role: "branch_manager")
  end

  test "admin forms include branch assignment and selectable permissions" do
    sign_in_as @admin
    get edit_branch_path(@annex)
    assert_response :success
    assert_select "input[name='branch[permission_mode]'][value='custom']"
    assert_select "input[name='branch[allowed_permissions][]'][value='sales.create']"
    assert_select "input[name='branch[allowed_permissions][]'][value='owner.manage']", count: 0
    get new_user_path(branch_id: @annex.id)
    assert_response :success
    assert_select "select[name='user[branch_id]'] option[selected][value='#{@annex.id}']"
    assert_select "select[name='user[branch_id]'] option[value='#{@foreign.id}']", count: 0
    assert_select "select[name='user[role]'] option[value='owner']", count: 0
    assert_select "input[name='user[custom_permissions][]'][value='reports.view']"
    get branch_path(@annex)
    assert_response :success
    assert_select "a[href='#{edit_user_path(@cashier)}']"
    assert_select "a[href='#{new_user_path(branch_id: @annex.id)}']"
  end

  test "admin can create a branch with a custom permission limit" do
    sign_in_as @admin
    post branches_path, params: { branch: { name: "North", branch_type: "sub", status: "active",
      permission_mode: "custom", allowed_permissions: ["sales.view", "sales.create", ""] } }
    assert_redirected_to branches_path
    branch = @business.branches.find_by!(name: "North")
    assert_equal %w[sales.view sales.create], branch.allowed_permissions
    assert_equal @admin.id, branch.provisioned_by_id
  end

  test "admin grants reports to a cashier and limits sales without changing branch scope" do
    sign_in_as @admin
    patch user_path(@cashier), params: { user: { permission_mode: "custom",
      custom_permissions: ["sales.view", "reports.view"], permissions_scope: "business" } }
    assert_redirected_to users_path
    assert_equal %w[sales.view reports.view], @cashier.reload.custom_permissions
    assert_equal "branch", @cashier.permissions_scope
    sign_in_as @cashier
    get sales_path
    assert_response :success
    assert_select "a[href='#{new_sale_path}']", count: 0
    assert_select "a[href='#{reports_path}']"
    get reports_path
    assert_response :success
    get new_sale_path
    assert_redirected_to access_denied_path
  end

  test "branch limits apply to an already signed in staff member on the next request" do
    @cashier.update!(custom_permissions: ["sales.view", "reports.view"])
    sign_in_as @cashier
    get reports_path
    assert_response :success
    @annex.update!(allowed_permissions: ["sales.view"])
    get reports_path
    assert_redirected_to access_denied_path
    get sales_path
    assert_response :success
    assert_select "a[href='#{reports_path}']", count: 0
    @annex.update!(allowed_permissions: nil)
    get reports_path
    assert_response :success
  end

  test "admin creates staff with the submitted role branch and permissions" do
    sign_in_as @admin
    post users_path, params: { user: { full_name: "Annex Accountant", username: "annex-accountant",
      password: "Passw0rd!123", password_confirmation: "Passw0rd!123", role: "accountant",
      branch_id: @annex.id, permission_mode: "custom", custom_permissions: ["reports.view"], status: "active" } }
    assert_redirected_to users_path
    user = User.find_by!(username: "annex-accountant")
    assert_equal "accountant", user.role
    assert_equal @annex.id, user.branch_id
    assert_equal @business.id, user.business_id
    assert user.can?("reports.view")
    refute user.can?("sales.create")
  end

  test "branch staff see their own branch but cannot manage staff or permissions" do
    sign_in_as @manager
    get branches_path
    assert_response :success
    assert_select "a[href='#{branch_path(@annex)}']"
    assert_select "a[href='#{branch_path(@main)}']", count: 0
    assert_select "a[href='#{edit_branch_path(@annex)}']", count: 0
    assert_select "a[href='#{users_path}']", count: 0
    get branch_path(@annex)
    assert_response :success
    assert_select "a[href='#{edit_user_path(@cashier)}']", count: 0
    get branch_path(@main)
    assert_response :not_found
    get users_path
    assert_redirected_to access_denied_path
    patch branch_path(@annex), params: { branch: { permission_mode: "custom", allowed_permissions: [] } }
    assert_redirected_to access_denied_path
    patch user_path(@manager), params: { user: { role: "shop_admin", permission_mode: "custom", custom_permissions: ["users.edit"] } }
    assert_redirected_to access_denied_path
    assert_equal "branch_manager", @manager.reload.role
    assert_nil @annex.reload.allowed_permissions
  end

  test "foreign branch assignments and administration grants are refused" do
    sign_in_as @admin
    patch user_path(@cashier), params: { user: { branch_id: @foreign.id } }
    assert_response :unprocessable_entity
    assert_equal @annex.id, @cashier.reload.branch_id
    patch user_path(@cashier), params: { user: { permission_mode: "custom", custom_permissions: ["users.edit", "*"] } }
    assert_response :unprocessable_entity
    assert_nil @cashier.reload.custom_permissions
    patch branch_path(@annex), params: { branch: { permission_mode: "custom", allowed_permissions: ["owner.manage"] } }
    assert_response :unprocessable_entity
    assert_nil @annex.reload.allowed_permissions
    get edit_branch_path(@foreign)
    assert_response :not_found
  end

  test "suspension blocks new logins and an existing staff session" do
    sign_in_as @cashier
    @annex.update!(status: "suspended")
    get sales_path
    assert_redirected_to login_path
    post login_path, params: { username: @cashier.username, password: "Passw0rd!123" }
    assert_response :unprocessable_entity
    @annex.update!(status: "active")
    post login_path, params: { username: @cashier.username, password: "Passw0rd!123" }
    assert_response :redirect
    get sales_path
    assert_response :success
  end

  test "assigned staff prevent branch deletion and admin can reassign them" do
    sign_in_as @admin
    delete branch_path(@annex)
    assert_redirected_to branches_path
    assert Branch.exists?(@annex.id)
    [@cashier, @manager].each do |user|
      patch user_path(user), params: { user: { branch_id: @main.id } }
      assert_redirected_to users_path
    end
    delete branch_path(@annex)
    assert_redirected_to branches_path
    refute Branch.exists?(@annex.id)
    assert_equal @main.id, @cashier.reload.branch_id
  end

  test "empty custom staff list is saved and default mode restores role permissions" do
    sign_in_as @admin
    patch user_path(@cashier), params: { user: { permission_mode: "custom", custom_permissions: [""] } }
    assert_redirected_to users_path
    assert_equal ["dashboard.view"], @cashier.reload.permissions
    patch user_path(@cashier), params: { user: { permission_mode: "default", custom_permissions: [] } }
    assert_redirected_to users_path
    assert_nil @cashier.reload.custom_permissions
    assert @cashier.can?("sales.create")
  end
end

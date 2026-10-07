require "test_helper"

class BranchPermissionsTest < ActiveSupport::TestCase
  setup do
    @business = create_business
    @branch = create_branch(business: @business)
    @cashier = create_user(business: @business, branch: @branch, role: "cashier")
  end

  test "staff defaults remain available until the admin sets a branch limit" do
    assert @cashier.can?("sales.create")
    @branch.update!(allowed_permissions: ["sales.view"])
    @cashier.reload
    assert @cashier.can?("sales.view")
    refute @cashier.can?("sales.create")
    assert @cashier.can?("dashboard.view")
  end

  test "custom staff permissions can add actions and branch policy caps them" do
    @cashier.update!(custom_permissions: ["reports.view", "sales.view"])
    assert @cashier.can?("reports.view")
    refute @cashier.can?("sales.create")
    @branch.update!(allowed_permissions: ["sales.view"])
    @cashier.reload
    refute @cashier.can?("reports.view")
    assert @cashier.can?("sales.view")
    @branch.update!(allowed_permissions: nil)
    @cashier.reload
    assert @cashier.can?("reports.view")
    @cashier.update!(custom_permissions: nil)
    refute @cashier.can?("reports.view")
    assert @cashier.can?("sales.create")
  end

  test "empty policy allows only dashboard and does not affect shop admins" do
    @branch.update!(allowed_permissions: [])
    @cashier.reload
    assert_equal ["dashboard.view"], @cashier.permissions
    admin = create_user(business: @business, branch: @branch)
    assert admin.can?("sales.create")
    assert admin.can?("users.edit")
  end

  test "administration platform wildcard and invented grants are rejected" do
    %w[users.create branches.edit owner.manage portal.view settings.edit * made_up.view].each do |grant|
      @cashier.custom_permissions = [grant]
      refute @cashier.valid?, "Staff should not accept #{grant}"
      @branch.allowed_permissions = [grant]
      refute @branch.valid?, "Branches should not accept #{grant}"
    end
  end

  test "changing main branch keeps a single default on update" do
    @branch.update!(is_default: true)
    refute @branch.update(is_default: false)
    @branch.reload
    other = create_branch(business: @business, name: "Annex", branch_type: "sub")
    other.update!(is_default: true)
    assert other.reload.default?
    refute @branch.reload.default?
    assert_equal 1, @business.branches.where(is_default: true).count
  end

  test "missing branch fails validation and cannot widen data access" do
    @cashier.branch_id = nil
    refute @cashier.valid?
    as(@cashier) do
      assert_empty Branch.shop
      assert_empty Sale.shop
    end
  end

  test "last active shop admin cannot be deactivated or demoted" do
    admin = create_user(business: @business)
    admin.status = "inactive"
    refute admin.valid?
    admin.status = "active"
    admin.role = "cashier"
    admin.branch = @branch
    refute admin.valid?
  end
end

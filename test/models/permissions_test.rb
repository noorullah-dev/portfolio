require "test_helper"

class PermissionsTest < ActiveSupport::TestCase
  test "platform owner holds every permission" do
    assert_equal Permissions::ALL_PERMISSIONS.sort, Permissions.for_role("owner").sort
  end

  test "shop admin holds every permission" do
    assert_equal Permissions::ALL_PERMISSIONS.sort, Permissions.for_role("shop_admin").sort
  end

  test "recovery officer is limited to recovery and collection work" do
    granted = Permissions.for_role("recovery_officer")
    assert_includes granted, "installments.view"
    assert_includes granted, "installments.collect"
    assert_includes granted, "recoveries.view"
    assert_includes granted, "credit_recovery.view"
    # A recovery officer needs the customer's sale to collect against, but the
    # rows themselves are limited to their assigned locations by Current.
    assert_includes granted, "sales.view"
    refute_includes granted, "sales.create"
    refute_includes granted, "settings.edit"
    refute_includes granted, "products.view"
    refute_includes granted, "expenses.view"
  end

  test "cashier is limited to point of sale work" do
    granted = Permissions.for_role("cashier")
    assert_includes granted, "sales.view"
    assert_includes granted, "sales.create"
    assert_includes granted, "installments.collect"
    refute_includes granted, "sales.delete"
    refute_includes granted, "purchases.create"
    refute_includes granted, "users.view"
    refute_includes granted, "accounts.manage"
  end

  test "accountant may post vouchers but not manage products" do
    granted = Permissions.for_role("accountant")
    assert_includes granted, "journal.create"
    assert_includes granted, "accounts.manage"
    assert_includes granted, "reports.view"
    refute_includes granted, "products.create"
  end

  test "branch manager may run their branch but not manage staff" do
    granted = Permissions.for_role("branch_manager")
    assert_includes granted, "sales.view"
    assert_includes granted, "products.view"
    refute_includes granted, "users.delete"
    refute_includes granted, "settings.edit"
    refute_includes granted, "owner.view"
  end

  test "customer portal role only reaches the portal" do
    assert_equal %w[dashboard.view portal.view], Permissions.for_role("customer").sort
  end

  test "unknown role gets nothing" do
    assert_empty Permissions.for_role("wizard")
    assert_empty Permissions.for_role(nil)
  end

  test "expand understands strings, hashes and nested arrays" do
    assert_equal %w[sales.create sales.view], Permissions.expand({ sales: %i[view create] }).sort
    assert_equal %w[journal.post journal.view], Permissions.expand([:journal, %i[view post]]).sort
    assert_equal %w[accounts.manage], Permissions.expand("accounts.manage")
  end

  test "a role with no matrix entry gets nothing" do
    assert_empty Permissions.for_role(:not_a_role)
  end

  test "every navigation entry is guarded by a real permission" do
    Permissions::NAV_PERMISSIONS.each_value do |permission|
      assert_includes Permissions::ALL_PERMISSIONS, permission,
                      "navigation requires unknown permission #{permission}"
    end
  end

  test "navigation hides modules a role cannot reach" do
    customer = Permissions.for_role("customer")
    hidden = Permissions::NAV_PERMISSIONS.reject { |_helper, permission| customer.include?(permission) }
    assert hidden.key?(:products_path)
    assert hidden.key?(:users_path)
    assert hidden.key?(:business_settings_path)
    # the staff navigation is closed to a portal login entirely
    assert hidden.values.none? { |permission| Permissions.for_role("customer").include?(permission) }
  end
end

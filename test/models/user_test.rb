require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @business = create_business(name: "Alpha Motors")
    @branch = create_branch(business: @business)
  end

  test "staff need a shop and a branch, the platform owner needs neither" do
    user = User.new(full_name: "Staff", username: "staff", password: "Passw0rd!123", role: "cashier")
    refute user.valid?
    assert_includes user.errors.full_messages.join, "shop"

    owner = User.new(full_name: "Boss", username: "boss", password: "Passw0rd!123", role: "owner")
    assert owner.valid?, owner.errors.full_messages.join(", ")
    assert_nil owner.business_id
    assert_nil owner.branch_id
  end

  test "legacy role names are accepted and migrated on save" do
    user = create_user(business: @business, role: "admin", branch: @branch)
    assert_equal "shop_admin", user.reload.role
    assert_equal "business", user.permissions_scope

    manager = create_user(business: @business, role: "manager", branch: @branch)
    assert_equal "branch_manager", manager.reload.role
    assert_equal "branch", manager.permissions_scope

    accounts = create_user(business: @business, role: "accounts", branch: @branch)
    assert_equal "accountant", accounts.reload.role
  end

  test "unknown roles are rejected" do
    user = User.new(username: "ghost", password: "Passw0rd!123", role: "wizard",
                    business: @business, branch: @branch)
    refute user.valid?
  end

  test "permissions scope follows the role" do
    # the owner is business wide as well - Current.cross_tenant? is what widens it
    assert_equal "business", create_user(role: "owner").permissions_scope
    assert_equal "business", create_user(business: @business, role: "shop_admin", branch: @branch).permissions_scope
    assert_equal "branch", create_user(business: @business, role: "cashier", branch: @branch).permissions_scope
  end

  test "customer logins must be linked to a customer account and no shop" do
    customer = Customer.create!(business: @business, name: "Portal Buyer", phone: "03009998888")
    portal = create_user(role: "customer", customer: customer)
    assert portal.customer_portal?
    assert_nil portal.business_id
    assert_nil portal.branch_id

    orphan = User.new(username: "orphan", password: "Passw0rd!123", role: "customer",
                      business: @business, branch: @branch)
    refute orphan.valid?
  end

  test "repeated failures lock the account for a while" do
    user = create_user(business: @business, role: "cashier", branch: @branch)
    assert user.status_active?
    assert_equal user.id, User.authenticate(user.username, "Passw0rd!123").id

    5.times { assert_nil User.authenticate(user.username, "wrong-password") }
    user.reload
    assert_equal User::MAX_FAILED_LOGINS, user.failed_login_count
    assert user.locked_until.present?
    assert user.locked?
    assert_nil User.authenticate(user.username, "Passw0rd!123")
  end

  test "a successful login resets the failure counter" do
    user = create_user(business: @business, role: "cashier", branch: @branch)
    3.times { assert_nil User.authenticate(user.username, "wrong") }
    assert_equal user.id, User.authenticate(user.username, "Passw0rd!123").id
    assert_equal 0, user.reload.failed_login_count
    assert_nil user.locked_until
  end

  test "inactive, locked and suspended accounts cannot sign in" do
    %w[inactive locked suspended].each do |status|
      user = create_user(business: @business, role: "cashier", branch: @branch, status: status)
      assert_nil User.authenticate(user.username, "Passw0rd!123"), "#{status} must not be allowed to sign in"
    end
  end

  test "usernames are global and case insensitive" do
    create_user(username: "FrontDesk", business: @business, branch: @branch)
    duplicate = User.new(full_name: "Dup", username: "frontdesk", password: "Passw0rd!123",
                         role: "cashier", business: @business, branch: @branch)
    refute duplicate.valid?
  end

  test "branch staff must belong to a branch of their own shop" do
    other_shop = create_business(name: "Beta Motors")
    foreign_branch = create_branch(business: other_shop, name: "Beta Main")
    user = User.new(full_name: "Sneaky", username: "sneaky", password: "Passw0rd!123",
                    role: "cashier", business: @business, branch: foreign_branch)
    refute user.valid?
    assert_includes user.errors.full_messages.join, "own shop"
  end

  test "a user may only be given locations of their own shop" do
    other_shop = create_business(name: "Beta Motors")
    foreign_location = create_location(business: other_shop, name: "Beta North")
    officer = create_user(business: @business, role: "recovery_officer", branch: @branch)
    officer.location_ids = [foreign_location.id]
    refute officer.valid?
    assert_includes officer.errors.full_messages.join, "own shop"

    own = create_location(business: @business, name: "Alpha North")
    officer.location_ids = [own.id]
    assert officer.valid?, officer.errors.full_messages.join(", ")
  end
end

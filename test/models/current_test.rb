require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup do
    @business = create_business(name: "Alpha Motors")
    @branch = create_branch(business: @business)
    @admin = create_user(business: @business, role: "shop_admin", branch: @branch)
  end

  test "shop admin gets business wide context and no location restriction" do
    as(@admin) do
      assert_equal @business, Current.business
      assert_equal "business", Current.permissions_scope
      refute Current.cross_tenant?
      assert_empty Current.location_ids
      assert_equal 1, Current.tenant_scope(Branch).count
    end
  end

  test "branch staff get a branch restricted context" do
    manager = create_user(business: @business, role: "branch_manager", branch: @branch)
    as(manager) do
      assert_equal "branch", Current.permissions_scope
      assert_equal @branch, Current.branch
      refute Current.cross_tenant?
      # reference data stays business wide
      assert_equal 1, Current.tenant_scope(Branch).count
    end
  end

  test "recovery officer is limited to assigned locations" do
    north = create_location(business: @business, name: "North")
    south = create_location(business: @business, name: "South")
    officer = create_user(business: @business, role: "recovery_officer", branch: @branch)
    UserLocation.create!(user: officer, location: north)

    as(officer) do
      assert_equal [north.id], Current.location_ids
      assert_equal [north.id], Current.tenant_scope(Location).pluck(:id)
      refute_includes Current.tenant_scope(Location).pluck(:id), south.id
    end
  end

  test "tenant scope fails closed without a business context" do
    Current.reset!
    assert_empty Current.tenant_scope(Sale)
    assert_empty Current.business_scope(Branch)
  end

  test "platform owner sees every shop" do
    other = create_business(name: "Beta Motors")
    create_branch(business: other, name: "Beta Branch")
    owner = create_user(role: "owner")

    as(owner) do
      assert_nil Current.business
      assert Current.cross_tenant?
      assert_includes Current.tenant_scope(Business).pluck(:id), other.id
    end
  end

  test "customer portal login carries no business context" do
    customer = create_customer_record
    portal = create_user(role: "customer", customer: customer)

    as(portal) do
      assert_nil Current.business
      assert EmptyRelationStub.matches?(Current.tenant_scope(Sale))
    end
  end

  test "records written in a request context are stamped with the tenant" do
    as(@admin) do
      brand = Brand.create!(name: "Bosch")
      category = Category.create!(name: "Filters")
      product = Product.create!(name: "Oil Filter", status: "active", brand: brand, category: category)
      assert_equal @business.id, product.business_id
    end

    manager = create_user(business: @business, role: "branch_manager", branch: @branch)
    as(manager) do
      product = Product.create!(name: "Branch Filter", status: "active",
                                brand: Brand.create!(name: "Bosch Branch"),
                                category: Category.create!(name: "Branch Filters"))
      assert_equal @branch.id, product.branch_id
      assert_equal @business.id, product.business_id
    end
  end

  test "shop wide reference data is written without a branch" do
    as(create_user(business: @business, role: "branch_manager", branch: @branch)) do
      brand = Brand.create!(name: "Bosch")
      assert_equal @business.id, brand.business_id
      assert_nil brand.branch_id
    end
  end

  private

  def create_customer_record
    business = @business
    Customer.create!(business: business, name: "Walk-in Customer", phone: "03001234567")
  end

  # Current.tenant_scope returns an ActiveRecord::Relation for a real table.
  module EmptyRelationStub
    def self.matches?(relation)
      relation.none?
    end
  end
end

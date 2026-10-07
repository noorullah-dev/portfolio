require "test_helper"

# Nothing a signed-in user can query may ever reach another shop's rows.
class TenantIsolationTest < ActiveSupport::TestCase
  setup do
    @alpha = create_business(name: "Alpha Motors")
    @beta = create_business(name: "Beta Motors")
    @alpha_branch = create_branch(business: @alpha, name: "Alpha Main")
    @alpha_second = create_branch(business: @alpha, name: "Alpha Annex")
    @beta_branch = create_branch(business: @beta, name: "Beta Main")
    @admin = create_user(business: @alpha, role: "shop_admin", branch: @alpha_branch)
    @manager = create_user(business: @alpha, role: "branch_manager", branch: @alpha_branch)
  end

  TENANT_MODELS = %w[
    Sale Purchase Product Customer Supplier Brand Category Agent
    InstallmentPlan PostDatedCheque StockUnit Voucher ChartOfAccount LedgerEntry
  ].freeze

  test "shop scope never returns another shop's rows" do
    as(@admin) do
      TENANT_MODELS.each do |name|
        model = name.constantize
        next unless model.column_names.include?("business_id")

        other = model.where(business_id: @beta.id)
        assert_equal 0, model.shop.merge(other).count,
                     "#{name}.shop leaked rows from the other shop"
      end
    end
  end

  test "branch staff are limited to their own branch" do
    other_branch_product = create_product(@alpha, branch: @alpha_second)

    as(@manager) do
      assert_equal 0, Product.shop.where(id: other_branch_product.id).count
      assert_equal 0, Branch.shop.where(id: @beta_branch.id).count
    end

    as(@admin) do
      assert_includes Product.shop.pluck(:id), other_branch_product.id
      assert_not_includes Branch.shop.pluck(:id), @beta_branch.id
    end
  end

  test "shop wide reference data is shared by every branch" do
    customer = Customer.create!(business: @alpha, name: "Shared Customer", phone: "03001234567")
    second_branch_customer = Customer.create!(business: @alpha, name: "Annex Customer", phone: "03007654321")

    as(@manager) do
      assert_includes Customer.shop.pluck(:id), customer.id
      assert_includes Customer.shop.pluck(:id), second_branch_customer.id
    end
  end

  test "recovery officers only see assigned locations" do
    north = create_location(business: @alpha, name: "North")
    south = create_location(business: @alpha, name: "South")
    north_customer = Customer.create!(business: @alpha, name: "North Buyer", phone: "03001111111", location: north)
    south_customer = Customer.create!(business: @alpha, name: "South Buyer", phone: "03002222222", location: south)
    officer = create_user(business: @alpha, role: "recovery_officer", branch: @alpha_branch)
    UserLocation.create!(user: officer, location: north)

    as(officer) do
      assert_includes Customer.shop.pluck(:id), north_customer.id
      assert_not_includes Customer.shop.pluck(:id), south_customer.id
      assert_equal [north.id], Location.shop.pluck(:id)
    end
  end

  test "recovery officer without assignments sees no customers at all" do
    create_location(business: @alpha, name: "North")
    Customer.create!(business: @alpha, name: "Somebody", phone: "03003333333")
    officer = create_user(business: @alpha, role: "recovery_officer", branch: @alpha_branch)

    as(officer) { assert_empty Customer.shop }
  end

  test "records created outside a request keep the tenant they were given" do
    beta_product = Product.create!(name: "Beta Only", status: "active",
                                   brand: Brand.create!(name: "Beta Brand"),
                                   category: Category.create!(name: "Beta Parts"),
                                   business: @beta)
    Current.reset!
    assert_equal @beta.id, beta_product.reload.business_id
  end

  test "platform owner is the only context that spans shops" do
    beta_product = create_product(@beta)
    alpha_product = create_product(@alpha)
    as(create_user(role: "owner")) do
      assert_includes Product.platform.pluck(:id), beta_product.id
      assert_includes Product.platform.pluck(:id), alpha_product.id
    end
  end

  test "tenant columns cannot be hijacked by request parameters" do
    as(@admin) do
      forged = Customer.new(business: @beta, name: "Forged")
      refute forged.save, "a row for another shop must not be creatable"
      assert_includes forged.errors.full_messages.join, "own shop"
      assert_equal 0, Customer.where(business_id: @beta.id, name: "Forged").count
    end
  end

  private

  def create_product(business, branch: nil)
    Product.create!(name: "Part #{SecureRandom.hex(3)}", status: "active",
                    brand: Brand.create!(name: "Brand #{SecureRandom.hex(2)}", business: business),
                    category: Category.create!(name: "Cat #{SecureRandom.hex(2)}", business: business),
                    business: business, branch: branch)
  end
end

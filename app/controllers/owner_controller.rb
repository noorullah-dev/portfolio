# Platform Owner console: provisions shops and their admins, and opens a shop so
# the owner can work inside it. The owner has no shop of their own: reads outside
# an open shop span every business, and every write happens inside the shop that
# is currently open (which the owner may do without any permission gate).
class OwnerController < ApplicationController
  guard all: "owner.view", new: "owner.manage", create: "owner.manage", edit: "owner.manage",
        update: "owner.manage", toggle_status: "owner.manage", create_admin: "owner.manage"

  before_action :require_owner!
  before_action -> { require_permission!("owner.manage") }, only: %i[new create edit update toggle_status]
  before_action :set_business, only: %i[show edit update toggle_status create_admin open]

  def index
    @businesses = Business.order(:name).map do |shop|
      {
        business: shop,
        branches: shop.branches.count,
        staff: shop.users.active.count,
        customers: shop.customers.count,
        sales: shop.sales.count,
        revenue: shop.sales.sum { |sale| sale.total_amount.to_d },
        owner: shop.users.where(role: "shop_admin", status: "active").first
      }
    end
    @platform = {
      shops: Business.count,
      active_shops: Business.where(status: "active").count,
      suspended_shops: Business.where(status: "suspended").count,
      branches: Branch.count,
      staff: User.where.not(role: %w[owner customer]).count,
      portal_logins: User.where(role: "customer").count
    }
  end

  def show
    @branches = @business.branches.ordered
    @staff = @business.users.order(:role, :full_name)
    @locations = @business.locations.ordered
    @recent_audit = AuditLog.where(business_id: @business.id).recent(30)
    @metrics = {
      customers: @business.customers.count,
      sales: @business.sales.count,
      sales_value: @business.sales.sum { |sale| sale.total_amount.to_d },
      receivables: @business.customers.sum { |customer| customer.balance.to_d }
    }
  end

  def new
    @business = Business.new(currency: "Rs.", business_type: "3", status: "active")
  end

  def create
    @business = Business.new(business_params)
    @business.provisioned_by = current_user

    if @business.save
      # A shop always needs a main branch and a default location before staff
      # can be assigned to it.
      branch = @business.branches.create!(name: "#{@business.name} Main Branch", branch_type: "main", is_default: true)
      location = @business.locations.create!(name: "Main Location", status: "active")
      redirect_to owner_business_path(@business), notice: "#{@business.name} created with its main branch and location."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @business.update(business_params)
      redirect_to owner_business_path(@business), notice: "Shop details updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Provision the shop's first shop admin. The password is shown once so the
  # owner can hand it over; the admin must change it on first login.
  def create_admin
    @user = @business.users.new(role: "shop_admin", status: "active",
                                 permissions_scope: "business",
                                 branch_id: @business.branches.find_by(is_default: true)&.id,
                                 provisioned_by: current_user)
    @user.full_name = params[:full_name].presence || "Shop Administrator"
    @user.username = params[:username].to_s.strip.downcase.presence || default_admin_username
    password = params[:password].presence || SecureRandom.base58(10)
    @user.password = password
    @user.password_confirmation = params[:password_confirmation].presence || password
    @user.must_change_password = true

    if @user.save
      Current.audit!(:"owner.provision_admin", record: @user,
                                            summary: "Provisioned admin #{@user.username} for #{@business.name}",
                                            subject_user: @user)
      redirect_to owner_business_path(@business), notice: "Admin #{@user.username} created with a temporary password."
    else
      @branches = @business.branches.ordered
      @staff = @business.users.order(:role, :full_name)
      @locations = @business.locations.ordered
      render :show, status: :unprocessable_entity
    end
  end

  def toggle_status
    new_status = @business.status == "suspended" ? "active" : "suspended"
    @business.update(status: new_status)
    @business.users.where.not(role: "owner").update_all(status: new_status == "suspended" ? "suspended" : "active")
    event = new_status == "suspended" ? :owner_suspend : :owner_reactivate
    Current.audit!(event, record: @business, summary: "#{@business.name} set to #{new_status}")
    redirect_to owner_business_path(@business), notice: "#{@business.name} is now #{new_status}."
  end

  # Opens a shop so the owner works inside it with every permission a shop
  # staff member has - the shop is stamped on all rows written from then on.
  def open
    session[:owner_business_id] = @business.id
    Current.audit!(:owner_open_shop, record: @business, summary: "Owner opened #{@business.name}")
    redirect_to root_path, notice: "Now working inside #{@business.name}. Use the shop switcher to change or close it."
  end

  # Back to the platform-wide view.
  def close
    session.delete(:owner_business_id)
    redirect_to owner_businesses_path, notice: "Back to the platform view."
  end

  private

  def require_owner!
    return if current_user&.owner?

    redirect_to root_path, alert: "The owner console is only available to the platform owner."
  end

  def set_business
    @business = Business.find(params[:id])
  end

  def business_params
    params.require(:business).permit(:name, :business_type, :currency, :address, :city, :phone, :email, :status)
  end

  def default_admin_username
    base = @business.slug.presence || @business.name.parameterize
    candidate = base
    suffix = 1
    while User.where("lower(username) = ?", candidate).exists?
      suffix += 1
      candidate = "#{base}.#{suffix}"
    end
    candidate
  end
end

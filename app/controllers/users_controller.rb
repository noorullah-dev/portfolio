# Shop Admins manage the staff of their own shop. They can never touch the
# platform owner, another shop's staff, or a login outside their own business.
class UsersController < ApplicationController
  guard index: "users.view", show: "users.view",
        new: "users.create", create: "users.create",
        edit: "users.edit", update: "users.edit",
        destroy: "users.delete"

  shop_admin_only
  before_action :set_user, only: %i[show edit update destroy]
  before_action :ensure_own_tenant!, only: %i[show edit update destroy]

  def index
    @users = manageable_users.order(:role, :full_name)
    @users = @users.where(role: params[:role]) if params[:role].present?
    @users = @users.where(status: params[:status]) if params[:status].present?
    @users = @users.where(branch_id: params[:branch_id]) if params[:branch_id].present?
  end

  def show
    @audit = AuditLog.for_tenant.where(subject_user_id: @user.id).recent(25)
  end

  def new
    @user = User.new(role: default_role, status: "active", business_id: tenant_business_id,
                     branch_id: params[:branch_id].presence || default_branch_for_assignment&.id,
                     permissions_scope: default_scope_for(default_role))
    @locations = assignable_locations
  end

  def edit
    @locations = assignable_locations
  end

  def create
    @user = User.new(user_params.merge(business_id: tenant_business_id, role: "cashier"))
    assign_role(@user, params.dig(:user, :role))
    @user.provisioned_by = current_user
    apply_role_setup(@user)
    set_password(@user, params.dig(:user, :password), confirmation: params.dig(:user, :password_confirmation))
    @user.username = @user.username.presence || generated_username

    if @user.save
      replace_locations(@user)
      Current.audit!(:"user.create", record: @user, summary: "Created login #{@user.username} (#{@user.role})",
                                    changes: audit_changes(@user), subject_user: @user)
      redirect_to users_path, notice: "User #{@user.username} created."
    else
      @locations = assignable_locations
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if params[:user].blank?
      return redirect_to users_path, alert: "Nothing to update."
    end

    attributes = params[:user]
    if attributes[:password].present?
      set_password(@user, attributes[:password], confirmation: attributes[:password_confirmation])
      @user.must_change_password = true if @user.password.present?
    end

    assign_role(@user, attributes[:role])

    # Nobody may set the "must change password" flag on their own account
    # through a normal edit; it is set when an admin resets somebody's password.
    permitted = user_params.except(:password, :password_confirmation)
    permitted = permitted.except(:must_change_password) if @user == current_user

    if @user.update(permitted)
      replace_locations(@user)
      Current.audit!(:"user.update", record: @user, summary: "Updated login #{@user.username}",
                                    changes: audit_changes(@user), subject_user: @user)
      redirect_to users_path, notice: "User #{@user.username} updated."
    else
      @locations = assignable_locations
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: "You cannot delete your own account."
    elsif last_admin?
      redirect_to users_path, alert: "At least one shop administrator must remain."
    else
      @user.update(status: "inactive")
      Current.audit!(:"user.deactivate", record: @user, summary: "Deactivated #{@user.username}",
                                        subject_user: @user)
      redirect_to users_path, notice: "User #{@user.username} deactivated."
    end
  end

  private

  # A shop admin only ever sees the staff of their own business; the owner works
  # inside the shop they opened (and otherwise reaches staff through the owner
  # console, since this screen is shop-admin only).
  def manageable_users
    owner? ? User.shop.order(:role, :full_name) : User.shop.where(business_id: current_user.business_id)
  end

  def tenant_business_id
    owner? ? Current.business_id : current_user.business_id
  end

  # The owner has no branch of their own, so a new staff login falls back to the
  # open shop's main branch.
  def default_branch_for_assignment
    current_user.default_branch ||
      business&.branches&.find_by(is_default: true) ||
      business&.branches&.ordered&.first
  end

  def set_user
    @user = User.shop.find(params[:id])
  end

  # Blocks cross-tenant access at the record level (defence in depth on top of
  # the User.shop scope).
  def ensure_own_tenant!
    return if @user.nil?
    return if owner?
    return if @user.business_id == current_user.business_id

    redirect_to users_path, alert: "That login belongs to another company."
  end

  def last_admin?
    manageable_users.where(role: "shop_admin", status: "active").where.not(id: @user.id).none?
  end

  def default_role
    role = params[:user]&.dig(:role).presence || params[:role]
    role = "cashier" unless User::ROLES.include?(role)
    role = "cashier" if role == "owner" && !owner?
    role
  end

  def default_scope_for(role)
    Permissions.branch_scoped_role?(role) ? "branch" : "business"
  end

  # Role changes only ever happen here - :role is not in user_params - so a shop
  # admin can never promote somebody (or themselves) to the platform owner.
  def assign_role(user, role)
    return if role.blank?
    return unless User::ROLES.include?(role)
    return if role == "owner" && !owner?

    if user == current_user && role != user.role && last_admin_for_user?(user)
      return
    end

    user.role = role
    user.permissions_scope = default_scope_for(role)
  end

  def last_admin_for_user?(user)
    user.role == "shop_admin" &&
      manageable_users.where(role: "shop_admin", status: "active").where.not(id: user.id).none?
  end

  # Customers are shop-wide; staff and recovery officers need a branch, and
  # recovery officers need at least one location.
  def apply_role_setup(user)
    user.permissions_scope = default_scope_for(user.role) if user.permissions_scope.blank?

    if user.customer_portal?
      user.branch_id = nil
      user.customer_id ||= params.dig(:user, :customer_id).presence
    elsif user.owner?
      user.business_id = nil
      user.branch_id = nil
    else
      user.business_id = tenant_business_id
      user.branch_id = params.dig(:user, :branch_id).presence || default_branch_for_assignment&.id
    end

    @pending_location_ids = requested_location_ids
  end

  def set_password(user, value, confirmation: nil)
    password = value.presence || generated_password
    user.password = password
    user.password_confirmation = confirmation.presence || password
    user.must_change_password = true
    @generated_password = password if value.blank?
  end

  def generated_password
    SecureRandom.base58(10)
  end

  def generated_username
    base = params.dig(:user, :full_name).to_s.parameterize
    base = "user" if base.blank?
    candidate = base.tr("-", ".")
    suffix = 1
    while User.where("lower(username) = ?", candidate).exists?
      suffix += 1
      candidate = "#{base.tr('-', '.')}.#{suffix}"
    end
    candidate
  end

  # ------------------------------------------------------- location handling
  def assignable_locations
    return Location.none if current_user.nil?
    return current_user.business.locations if current_user.business

    Location.none
  end

  def requested_location_ids
    raw = params.dig(:user, :location_ids) || params[:location_ids]
    Array(raw).reject(&:blank?).map(&:to_i)
  end

  def replace_locations(user)
    return if user.owner? || user.customer_portal?
    return unless params[:user]&.key?(:location_ids) || params.key?(:location_ids)

    ids = requested_location_ids
    valid = assignable_locations.where(id: ids).pluck(:id)
    user.user_locations.where.not(location_id: valid).destroy_all
    (valid - user.user_locations.pluck(:location_id)).each do |location_id|
      user.user_locations.create(location_id: location_id)
    end
  end

  # :role is deliberately absent - see #assign_role. :customer_id is only used to
  # link a portal login to its account.
  def user_params
    input = params.require(:user)
    attributes = input.permit(:username, :full_name, :phone, :status,
                                 :must_change_password, :branch_id, :customer_id,
                                 location_ids: [])
    if input[:permission_mode].present?
      attributes[:custom_permissions] = input[:permission_mode] == "custom" ? Array(input.permit(custom_permissions: [])[:custom_permissions]).reject(&:blank?) : nil
    end
    attributes
  end

  def audit_changes(user)
    { "full_name" => user.full_name, "role" => user.role, "status" => user.status,
      "branch_id" => user.branch_id, "permissions_scope" => user.permissions_scope,
      "custom_permissions" => user.custom_permissions }
  end
end

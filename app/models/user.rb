class User < ApplicationRecord
  include TenantScoped

  ROLES = %w[owner shop_admin branch_manager accountant cashier recovery_officer customer].freeze
  # Roles kept so old links/data keep working; they behave like their successor.
  LEGACY_ROLES = { "admin" => "shop_admin", "manager" => "branch_manager",
                   "accounts" => "accountant", "staff" => "cashier" }.freeze
  SCOPES = %w[business branch].freeze
  STATUSES = %w[active inactive locked suspended].freeze

  MAX_FAILED_LOGINS = 5
  LOCKOUT_MINUTES = 15

  has_secure_password

  belongs_to :business, optional: true          # NULL for the platform owner and portal users
  belongs_to :branch, optional: true
  belongs_to :customer, optional: true          # only for portal logins
  belongs_to :provisioned_by, class_name: "User", optional: true

  has_many :user_locations, dependent: :destroy
  has_many :locations, through: :user_locations
  has_many :branches, through: :branch
  has_many :owned_customers, class_name: "Customer", foreign_key: :salesman_id,
                             dependent: :nullify

  validates :full_name, presence: true
  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-zA-Z0-9._-]+\z/, message: "may only contain letters, numbers, dot, dash and underscore" }
  validates :role, inclusion: { in: ROLES }
  validates :permissions_scope, inclusion: { in: SCOPES }
  validate :customer_portal_is_consistent
  validate :owner_has_no_tenant
  validate :tenant_required_for_staff
  validate :branch_belongs_to_business
  validate :locations_belong_to_business
  validate :custom_permissions_are_valid
  validate :last_active_admin_is_preserved

  scope :active, -> { where(status: "active").order(:full_name) }
  scope :by_role, ->(role) { where(role: role) }
  scope :platform_owners, -> { where(role: "owner") }

  before_validation :normalize_username
  before_validation :normalize_legacy_role
  before_validation :apply_role_defaults
  before_validation :normalize_custom_permissions

  ROLES.each do |role_name|
    define_method(:"#{role_name}?") { role == role_name }
  end

  class << self
    def authenticate(username_or_name, password)
      user = find_by("lower(username) = :value OR lower(full_name) = :value",
                     value: username_or_name.to_s.strip.downcase)
      return nil if user.nil?

      user.unlock! if user.lockout_expired?
      return nil if user.locked?
      return nil unless user.access_active?

      if user.authenticate(password)
        user.register_successful_login!
        user
      else
        user.register_failed_login!
        nil
      end
    end

    def role_options = Permissions.role_options

    def permissions_for(role) = Permissions.for_role(role)
  end

  # ------------------------------------------------------------------ auth
  def permission
    return Permissions.for_role(role).to_set if owner? || shop_admin? || customer_portal?

    granted = (custom_permissions || Permissions.for_role(role)) & Permissions::STAFF_PERMISSIONS
    granted &= branch.allowed_permissions unless branch&.allowed_permissions.nil?
    (granted + ["dashboard.view"]).to_set
  end

  def permissions
    permission.to_a
  end

  def can?(perm)
    return true if perm.to_s == Permissions::ALL
    return false if perm.blank?

    permission.include?(perm.to_s)
  end

  def can_any?(*perms) = perms.flatten.any? { |p| can?(p) }

  def can_all?(*perms) = perms.flatten.all? { |p| can?(p) }

  # ------------------------------------------------------------- roles/tenancy
  def owner? = role == "owner"

  def shop_admin? = role == "shop_admin"

  def branch_manager? = role == "branch_manager"

  def accountant? = role == "accountant"

  def cashier? = role == "cashier"

  def recovery_officer? = role == "recovery_officer"

  def customer_portal? = role == "customer"

  def platform_level? = owner?

  def staff_of_shop? = !owner? && !customer_portal?

  # True for a recovery officer even when no location has been assigned yet -
  # Current then returns an empty scope instead of quietly lifting the filter.
  def location_scoped? = Permissions.location_scoped_role?(role)

  # Reads the assignment table directly: #location_ids can be satisfied from an
  # unloaded has_many :through target and would silently answer [].
  def assigned_location_ids
    user_locations.pluck(:location_id)
  end

  def branch_scoped? = !permissions_scope_business? && branch_id.present?

  def permissions_scope_business? = permissions_scope == "business"

  def all_branches? = permissions_scope_business? || owner?

  def business_scoped? = business_id.present?

  def default_branch = branch || business&.branches&.find_by(is_default: true) || business&.branches&.ordered&.first

  def tenant_name = business&.name || "Platform"

  def tenant_label
    return "Platform Owner" if owner?
    return "Customer" if customer_portal?
    return "#{business&.name}#{branch ? " / #{branch.name}" : ''}" if branch

    business&.name.to_s
  end

  # ------------------------------------------------------------------ state
  def display_role = Permissions.role_options.to_h[role] || role.to_s.humanize

  def can_manage_accounts? = can?("users.view")

  def can_view_reports? = can?("reports.view")

  def status_active? = status == "active"

  def access_active?
    return false unless status_active?
    return true if owner? || customer_portal?
    return false unless business&.status == "active"
    return true if shop_admin?

    branch&.status == "active"
  end

  def locked?
    locked_until.present? && locked_until > Time.current
  end

  def lockout_expired?
    locked_until.present? && locked_until <= Time.current
  end

  def unlock!
    update!(status: "active", locked_until: nil, failed_login_count: 0)
  end

  # must_change_password is deliberately left alone: a temporary password has
  # to survive the login that used it, otherwise the forced change never happens.
  def register_successful_login!
    update_columns(last_login_at: Time.current, failed_login_count: 0, locked_until: nil)
  end

  def register_failed_login!
    self.failed_login_count = failed_login_count.to_i + 1
    if failed_login_count >= MAX_FAILED_LOGINS
      self.locked_until = MAX_FAILED_LOGINS.minutes.from_now
      self.status = "locked"
    end
    save(validate: false)
  end

  # Locations this user may work in (nil when not location-scoped).
  def allowed_location_ids
    return nil unless location_scoped?

    location_ids
  end

  # Applies the tenant defaults used by Current + the controllers.
  def establish_context!
    Current.set_from(self)
  end

  def display_tenant
    "#{business&.name}#{branch ? " / #{branch.name}" : ''}"
  end

  private

  def normalize_custom_permissions
    self.custom_permissions = custom_permissions.map(&:to_s).reject(&:blank?).uniq unless custom_permissions.nil?
    self.custom_permissions = nil if owner? || shop_admin? || customer_portal?
  end

  def custom_permissions_are_valid
    unknown = Array(custom_permissions) - Permissions::STAFF_PERMISSIONS
    errors.add(:custom_permissions, "contains permissions that cannot be assigned to branch staff") if unknown.any?
  end

  def last_active_admin_is_preserved
    return unless persisted? && role_in_database == "shop_admin" && status_in_database == "active"
    return if shop_admin? && status_active?
    return if User.where(business_id: business_id_in_database, role: "shop_admin", status: "active").where.not(id: id).exists?

    errors.add(:base, "At least one active shop administrator must remain.")
  end

  # admin -> shop_admin and friends, so a legacy link keeps working.
  def normalize_legacy_role
    self.role = LEGACY_ROLES.fetch(role.to_s, role) if role.present?
  end

  # A branch and a location always have to belong to the user's own shop.
  def branch_belongs_to_business
    return if branch_id.blank? || business_id.blank?
    return if Branch.exists?(id: branch_id, business_id: business_id)

    errors.add(:branch_id, "must belong to your own shop")
  end

  def locations_belong_to_business
    return if location_ids.blank? || business_id.blank?
    return if Location.where(id: location_ids).where(business_id: business_id).count == location_ids.uniq.count

    errors.add(:location_ids, "must all belong to your own shop")
  end

  def normalize_username
    self.username = username.to_s.strip.downcase if username.present?
  end

  # The role decides the data scope; there is no free-form override, so a
  # branch manager can never end up shop-wide by accident.
  def apply_role_defaults
    if owner?
      self.business_id = nil
      self.branch_id = nil
      self.customer_id = nil
      self.permissions_scope = "business"
    elsif customer_portal?
      self.branch_id = nil
      self.permissions_scope = "business"
    elsif role.present?
      self.permissions_scope = Permissions.branch_scoped_role?(role) ? "branch" : "business"
    end
  end

  def customer_portal_is_consistent
    return unless customer_portal?

    errors.add(:customer_id, "is required for a customer portal login") if customer_id.blank?
    errors.add(:branch_id, "is not used by customer logins") if branch_id.present?
  end

  def owner_has_no_tenant
    return unless owner? && (business_id.present? || branch_id.present?)

    errors.add(:business_id, "must be empty for the platform owner")
  end

  def tenant_required_for_staff
    return if owner? || customer_portal?
    errors.add(:business_id, "is required for shop staff") if business_id.blank?
    errors.add(:branch_id, "is required for branch staff") if !shop_admin? && branch_id.blank?
  end
end

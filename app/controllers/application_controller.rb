class ApplicationController < ActionController::Base
  include Pageable
  include PermissionGuards

  # The native app gets its own chrome-free shell; everything else keeps the
  # sidebar/topbar layout. Subclasses (the sign-in screen) may still override it.
  layout :app_layout

  before_action :require_login
  before_action :enforce_active_account!
  around_action :with_current_context
  before_action :force_password_change!
  before_action :enforce_portal_user
  before_action :store_user_timezone
  before_action :apply_device_variant
  before_action :enforce_owner_open_shop

  helper_method :current_user, :business, :branch, :signed_in?, :current_open_groups,
                :can?, :can_any?, :owner?, :shop_admin?, :location_restricted?, :assigned_locations,
                :allowed_location_ids, :location_allowed?, :visible_nav?,
                :native_app?, :acting_shop?, :owner_shop

  # flash messages are built in controllers, so the formatters have to be
  # available here too, not only in the views
  include MoneyFormat

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def signed_in?
    current_user.present?
  end

  # The tenant this request runs in. For the platform owner it is the shop they
  # opened from the owner console (nil until they do), so the same helpers,
  # partials and queries work for every role.
  def business
    @business ||= Current.business || current_user&.business
  end

  def branch
    @branch ||= Current.branch || current_user&.branch
  end

  def owner? = current_user&.owner?

  def shop_admin? = current_user&.shop_admin?

  # True while the owner is working inside a shop they opened.
  def acting_shop? = Current.acting?

  # The shop the owner currently has open (nil = platform view only).
  def owner_shop
    return @owner_shop if defined?(@owner_shop)

    id = session[:owner_business_id]
    @owner_shop = id.present? ? Business.find_by(id: id) : nil
    session.delete(:owner_business_id) if id.present? && @owner_shop.nil?
    @owner_shop
  end

  # ------------------------------------------------------------------ context
  # Sets the tenant context from the signed-in user and guarantees it is cleared
  # again, so no request can inherit the previous one's identity. The owner
  # additionally adopts the shop they opened in the owner console, which is what
  # grants them every action inside that shop.
  def with_current_context(&block)
    Current.set_from(current_user)
    Current.act_as(owner_shop) if owner?
    block.call
  ensure
    Current.reset!
  end

  # Customer portal logins must never reach the staff application, and staff
  # logins must never reach the portal.
  def enforce_portal_user
    return if current_user.nil?

    if current_user.customer_portal? && !portal_request?
      redirect_to customer_portal_path, alert: "Please use the customer portal."
      return
    end

    return unless portal_request? && !current_user.customer_portal?

    redirect_to root_path, alert: "This area is for customer logins."
  end

  # "/portal" itself and everything below it ("/portal/statement") counts as a
  # portal request; comparing only against a "/portal/" prefix made the portal
  # root redirect to itself forever.
  def portal_request?
    root = Rails.application.routes.url_helpers.customer_root_path
    request.path == root || request.path.start_with?("#{root}/")
  end

  # ---------------------------------------------------------------- native app
  # Hotwire Native (and legacy Turbo Native) clients are identified by their
  # User-Agent; ?native=1 / ?native=0 toggles it from a desktop browser so the
  # native layout can be developed without a phone. The choice is remembered for
  # the session so a redirect in the middle of a flow cannot drop it.
  def native_app?
    return @native_app if defined?(@native_app)

    if params[:native] == "1"
      session[:qm_native] = true
    elsif params[:native] == "0"
      session.delete(:qm_native)
    end

    @native_app = turbo_native_app? || session[:qm_native] == true
  end

  # Renders app/views/*.html+native.erb variants and the native layout.
  def apply_device_variant
    request.variant = :native if native_app?
  end

  def app_layout
    native_app? ? "native" : "application"
  end

  # Screens that stay writable for the owner without an open shop: the owner
  # console itself, the session, the password screen and the refusal page.
  OWNER_WRITE_CONTROLLERS = %w[owner passwords sessions access_denied].freeze

  # The owner holds every permission, but a shop action only means something
  # inside one shop. Until a shop is opened every shop screen stays read-only
  # (the platform-wide oversight view) and form screens point back to the owner
  # console; once a shop is open the owner may run every action in it.
  def enforce_owner_open_shop
    return if current_user.nil?
    return unless current_user.owner?
    return if OWNER_WRITE_CONTROLLERS.include?(controller_path)
    return if acting_shop?

    mutating = !(request.get? || request.head? || request.options?)
    form_screen = %w[new edit].include?(action_name)
    return unless mutating || form_screen

    redirect_to owner_businesses_path,
                alert: "Open a shop from the owner console first - owners have full access to every action inside an open shop."
  end

  # A login issued with a temporary password must be replaced before it can be
  # used for anything else.
  def force_password_change!
    return if current_user.nil?
    return unless current_user.must_change_password?
    return if controller_path == "passwords"
    return if controller_path == "sessions" || controller_name == "sessions"

    redirect_to change_password_path, alert: "Please set a new password before continuing."
  end

  # ------------------------------------------------------------ authorization
  def can?(permission) = current_user&.can?(permission)

  def can_any?(*permissions) = current_user&.can_any?(*permissions)

  def authorize!(permission)
    return true if can?(permission)

    audit_denied(permission)
    redirect_to access_denied_path, alert: "You do not have permission to #{action_name} here."
    false
  end

  def require_permission!(permission)
    authorize!(permission)
  end

  def authorize_any!(*permissions)
    return true if can_any?(permissions)

    audit_denied(permissions.join(", "))
    redirect_to access_denied_path, alert: "You do not have permission to open that page."
    false
  end

  def require_admin!
    authorize!("users.view")
  end

  def require_shop_admin!
    return if shop_admin?

    # Staff administration is per shop: the owner gets the same reach as a shop
    # admin as soon as they open a shop, and is otherwise sent to the console
    # to pick one (a nil business used to crash these screens).
    if owner?
      return if acting_shop?

      redirect_to owner_businesses_path, alert: "Open a shop from the owner console to manage its branches and staff."
      return
    end

    audit_denied("shop_admin")
    redirect_to access_denied_path, alert: "Only a shop administrator can manage branches and staff permissions."
  end

  def require_role!(*roles)
    return true if roles.include?(current_user&.role)

    authorize!(roles.join("/"))
  end

  def audit_denied(permission)
    AuditLog.write!(
      action: "access.denied",
      summary: "#{current_user&.username} was denied #{permission}",
      request: request
    )
  end

  # ---------------------------------------------------------- location scoping
  def location_restricted? = current_user&.location_scoped?

  def allowed_location_ids = current_user&.allowed_location_ids

  def assigned_locations
    return Location.none if current_user.nil?

    if current_user.location_scoped?
      Location.shop.where(id: current_user.location_ids)
    elsif business
      business.locations
    else
      Location.none
    end
  end

  def location_allowed?(location)
    return true if location.nil?
    return true unless location_restricted?

    allowed_location_ids.include?(location.id)
  end

  # Owner oversight: an owner may inspect one shop read-only.
  def overseen_business
    return nil unless owner?

    @overseen_business ||= begin
      candidate = params[:business_id].present? ? Business.find_by(id: params[:business_id]) : Business.first
      candidate
    end
  end

  # Every shop write the owner performs has to name a shop first. Inside an
  # open shop the owner is unrestricted, so this is only a guard rail for the
  # platform-wide view.
  def require_open_shop!(what = "change shop data")
    return unless owner?
    return if acting_shop?

    redirect_back fallback_location: owner_businesses_path,
                  alert: "Open a shop from the owner console first - owners have full access inside an open shop (to #{what})."
  end

  # ------------------------------------------------------------------- login
  def require_login
    return if signed_in?

    session[:return_to] = request.fullpath if request.get?
    redirect_to login_path, alert: "Please sign in to continue."
  end

  def enforce_active_account!
    return unless current_user && !current_user.access_active?

    sign_out
    redirect_to login_path, alert: "Your account, business, or branch is inactive. Contact your administrator."
  end

  def sign_in(user)
    reset_session
    session[:user_id] = user.id
    session[:open_nav_groups] = Array(session[:open_nav_groups])
    @current_user = user
    Current.set_from(user)
    AuditLog.write!(action: "session.start", summary: "#{user.username} signed in", request: request)
  end

  def sign_out
    username = current_user&.username
    AuditLog.write!(action: "session.end", summary: "#{username} signed out", request: request) if current_user
    reset_session
    @current_user = nil
    Current.reset!
  end

  def store_user_timezone
    cookies.permanent[:timezone] = params[:tz] if params[:tz].present?
  end

  def current_open_groups
    Array(session[:open_nav_groups])
  end

  def toggle_nav_group(key)
    groups = Array(session[:open_nav_groups])
    groups = groups.include?(key) ? groups - [key] : groups + [key]
    session[:open_nav_groups] = groups
  end

  def redirect_back_or(default)
    redirect_to(session[:return_to].presence || default)
  end
end

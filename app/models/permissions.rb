# The single source of truth for "who may do what".
#
# Roles are hierarchical but every permission is explicit, so a screen can ask
# `require_permission! :sales.create` and the menu can be filtered with the same
# list. Permissions are grouped per module so a new branch role inherits a sane
# default through ROLE_GROUPS.
module Permissions
  ALL = "*".freeze

  MODULES = {
    dashboard: %i[view],
    products: %i[view create edit delete],
    brands: %i[view create edit delete],
    categories: %i[view create edit delete],
    variants: %i[view create edit delete],
    suppliers: %i[view create edit delete ledger],
    agents: %i[view create edit delete],
    commissions: %i[view create edit delete],
    customers: %i[view create edit delete portal_access],
    sales: %i[view create edit delete cancel],
    quotations: %i[view create edit delete accept],
    stock: %i[view edit reserve],
    purchases: %i[view create edit delete pay],
    bookings: %i[view create edit delete collect],
    installments: %i[view collect remind transfer close],
    recoveries: %i[view manage],
    credit_recovery: %i[view manage],
    vehicle_documents: %i[view manage],
    registration: %i[view manage],
    vouchers: %i[view create post],
    journal: %i[view create post],
    expenses: %i[view create edit delete],
    accounts: %i[view create edit delete manage],
    cash_book: %i[view],
    reports: %i[view],
    calculator: %i[view],
    branches: %i[view create edit delete],
    users: %i[view create edit delete],
    settings: %i[view edit],
    audit: %i[view],
    owner: %i[view manage],
    portal: %i[view]
  }.freeze

  # Flat list of every concrete permission string.
  ALL_PERMISSIONS = MODULES.flat_map { |mod, actions| actions.map { |a| "#{mod}.#{a}" } }.freeze

  # Staff may receive business actions, but only a shop admin manages access.
  STAFF_PERMISSIONS = ALL_PERMISSIONS.reject do |permission|
    %w[owner portal users settings audit].include?(permission.split(".").first) ||
      permission.start_with?("branches.") && permission != "branches.view"
  end.freeze

  def self.staff_permission_groups
    STAFF_PERMISSIONS.reject { |permission| permission == "dashboard.view" }
                     .group_by { |permission| permission.split(".").first }
  end

  # Convenience bundles.
  READ_ONLY = MODULES.keys.map { |mod| "#{mod}.view" }.freeze

  # Roles that only work inside the locations assigned to them.
  LOCATION_SCOPED_ROLES = %w[recovery_officer].freeze

  # Roles that operate on a single branch rather than the whole shop.
  BRANCH_SCOPED_ROLES = %w[branch_manager accountant cashier recovery_officer].freeze

  # Platform level (business_id is NULL).
  OWNER_ROLES = %w[owner].freeze

  # Shop level roles.
  SHOP_ROLES = %w[shop_admin].freeze

  # Customer portal login.
  PORTAL_ROLES = %w[customer].freeze

  BY_ROLE = {
    # ------------------------------------------------------------ platform
    "owner" => ALL_PERMISSIONS + %w[owner.view owner.manage],

    # ---------------------------------------------------------------- shop
    "shop_admin" => ALL_PERMISSIONS,

    # -------------------------------------------------------------- branch
    "branch_manager" => ALL_PERMISSIONS - %w[users.delete settings.edit owner.view owner.manage],

    "accountant" => [
      dashboard: :view,
      customers: %i[view],
      suppliers: %i[view ledger],
      agents: %i[view],
      commissions: %i[view],
      sales: %i[view],
      quotations: %i[view],
      stock: %i[view],
      purchases: %i[view pay],
      bookings: %i[view collect],
      installments: %i[view collect remind transfer close],
      recoveries: %i[view manage],
      credit_recovery: %i[view manage],
      vehicle_documents: %i[view],
      registration: %i[view],
      vouchers: %i[view create post],
      journal: %i[view create post],
      expenses: %i[view create edit delete],
      accounts: %i[view manage],
      cash_book: %i[view],
      reports: %i[view],
      calculator: %i[view],
      branches: %i[view]
    ],

    "cashier" => [
      dashboard: :view,
      customers: %i[view create edit],
      suppliers: %i[view],
      sales: %i[view create edit],
      quotations: %i[view create accept],
      stock: %i[view reserve],
      purchases: %i[view],
      bookings: %i[view create],
      installments: %i[view collect],
      recoveries: %i[view],
      credit_recovery: %i[view],
      vehicle_documents: %i[view manage],
      registration: %i[view manage],
      vouchers: %i[view create],
      cash_book: %i[view],
      calculator: %i[view],
      branches: %i[view]
    ],

    "recovery_officer" => [
      dashboard: :view,
      customers: %i[view],
      sales: %i[view],
      installments: %i[view collect remind],
      recoveries: %i[view manage],
      credit_recovery: %i[view manage],
      agents: %i[view],
      branches: %i[view]
    ],

    # --------------------------------------------------------------- portal
    "customer" => [dashboard: :view, portal: :view]
  }.freeze

  class << self
    def for_role(role)
      raw = BY_ROLE.fetch(role.to_s, [])
      raw.flat_map { |entry| expand(entry) }.uniq
    end

    # Accepts a bare permission string ("sales.create"), a hash
    # (sales: %i[view create]) or a [module, actions] pair.
    def expand(entry)
      case entry
      when String then [entry]
      when Array  then Array(entry.last).map { |a| "#{entry.first}.#{a}" }
      when Hash   then entry.flat_map { |mod, actions| Array(actions).map { |a| "#{mod}.#{a}" } }
      else []
      end
    end

    def known?(permission)
      permission.to_s == ALL || ALL_PERMISSIONS.include?(permission.to_s)
    end

    def location_scoped_role?(role)
      LOCATION_SCOPED_ROLES.include?(role.to_s)
    end

    def branch_scoped_role?(role)
      BRANCH_SCOPED_ROLES.include?(role.to_s)
    end

    def owner_role?(role)
      OWNER_ROLES.include?(role.to_s)
    end

    def portal_role?(role)
      PORTAL_ROLES.include?(role.to_s)
    end

    # Role metadata used by the forms and the docs.
    def role_options
      [
        ["owner", "Platform Owner (all shops)"],
        ["shop_admin", "Shop Admin (whole company)"],
        ["branch_manager", "Branch Manager (one branch)"],
        ["accountant", "Accountant (finance, one branch)"],
        ["cashier", "Cashier (sales counter)"],
        ["recovery_officer", "Recovery Officer (assigned locations)"],
        ["customer", "Customer Portal Login"]
      ]
    end

  end

  # Navigation entries that require a permission, keyed by the path helper.
  NAV_PERMISSIONS = {
    customers_path: "customers.view",
    brands_path: "brands.view",
    categories_path: "categories.view",
    products_path: "products.view",
    variants_path: "variants.view",
    suppliers_path: "suppliers.view",
    new_purchase_path: "purchases.create",
    purchases_path: "purchases.view",
    stock_units_path: "stock.view",
    new_sale_path: "sales.create",
    sales_path: "sales.view",
    quotations_path: "quotations.view",
    qist_calculator_path: "calculator.view",
    vehicle_documents_path: "vehicle_documents.view",
    new_advance_booking_path: "bookings.create",
    advance_bookings_path: "bookings.view",
    credit_recoveries_path: "credit_recovery.view",
    installment_collections_path: "installments.view",
    post_dated_cheques_path: "installments.view",
    roznamcha_path: "installments.view",
    short_payments_path: "recoveries.view",
    account_transfers_path: "installments.transfer",
    account_closures_path: "installments.close",
    agents_path: "agents.view",
    agent_commissions_path: "commissions.view",
    registration_trackings_path: "registration.view",
    chart_of_accounts_path: "accounts.view",
    journal_vouchers_path: "journal.view",
    payment_vouchers_path: "vouchers.view",
    receipt_vouchers_path: "vouchers.view",
    expenses_path: "expenses.view",
    cash_book_path: "cash_book.view",
    reports_path: "reports.view",
    business_settings_path: "settings.edit",
    users_path: "users.view",
    branches_path: "branches.view",
    locations_path: "branches.view",
    audit_logs_path: "audit.view"
  }.freeze
end

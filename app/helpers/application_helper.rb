module ApplicationHelper
  # Declarative mirror of the captured sidebar. Keys are the original .aspx
  # targets, values are Rails routes, so the markup stays identical to the
  # capture while every link is a real Rails path.
  NAV_SECTIONS = [
    { label: "MAIN" },
    { label: nil, items: [
      { text: "Dashboard", icon: "bi-speedometer2", path: :root_path, permission: "dashboard.view" },
      { text: "Shops", icon: "bi-buildings", path: :owner_businesses_path, permission: "owner.view" }
    ] },
    { label: nil, items: [
      { text: "Products", icon: "bi-box-seam", key: "products", children: [
        { text: "Brands", icon: "bi-tag", path: :brands_path },
        { text: "Categories", icon: "bi-grid-3x3-gap", path: :categories_path },
        { text: "Products", icon: "bi-box", path: :products_path },
        { text: "Variants", icon: "bi-collection", path: :variants_path }
      ] }
    ] },
    { label: "TRANSACTIONS", keys: %w[purchase sales] },
    { label: nil, items: [
      { text: "Purchase", icon: "bi-truck", key: "purchase", children: [
        { text: "Suppliers", icon: "bi-truck", path: :suppliers_path },
        { text: "New Purchase", icon: "bi-plus-circle", path: :new_purchase_path },
        { text: "Purchase List", icon: "bi-list-ul", path: :purchases_path },
        { text: "Stock List", icon: "bi-boxes", path: :stock_units_path }
      ] },
      { text: "Sales", icon: "bi-receipt", key: "sales", children: [
        { text: "New Sale", icon: "bi-plus-circle", path: :new_sale_path },
        { text: "Sales List", icon: "bi-list-ul", path: :sales_path },
        { text: "Quotation", icon: "bi-file-earmark-text", path: :quotations_path },
        { text: "Qist Calculator", icon: "bi-calculator", path: :qist_calculator_path },
        { text: "Vehicle Documents", icon: "bi-file-earmark-text", path: :vehicle_documents_path },
        { text: "New Booking", icon: "bi-calendar-plus", path: :new_advance_booking_path },
        { text: "Booking List", icon: "bi-calendar-check", path: :advance_bookings_path },
        { text: "Credit Recovery", icon: "bi-cash-stack", path: :credit_recoveries_path }
      ] },
      { text: "Customers", icon: "bi-people", path: :customers_path }
    ] },
    { label: "INSTALLMENTS", keys: %w[installments agents] },
    { label: nil, items: [
      { text: "Installments", icon: "bi-calendar-check", key: "installments", children: [
        { text: "Collection", icon: "bi-wallet2", path: :installment_collections_path },
        { text: "PDC Cheques", icon: "bi-cash-coin", path: :post_dated_cheques_path },
        { text: "Roznamcha", icon: "bi-journal-text", path: :roznamcha_path },
        { text: "Short Tracker", icon: "bi-exclamation-triangle", path: :short_payments_path },
        { text: "Transfer", icon: "bi-arrow-left-right", path: :account_transfers_path },
        { text: "Closure", icon: "bi-x-circle", path: :account_closures_path }
      ] },
      { text: "Agents", icon: "bi-person-badge", key: "agents", children: [
        { text: "Agent List", icon: "bi-person-lines-fill", path: :agents_path },
        { text: "Commissions", icon: "bi-percent", path: :agent_commissions_path },
        { text: "Registration Tracking", icon: "bi-card-checklist", path: :registration_trackings_path }
      ] }
    ] },
    { label: "FINANCE", keys: %w[accounts reports settings] },
    { label: nil, items: [
      { text: "Accounts", icon: "bi-journal-text", key: "accounts", children: [
        { text: "Chart of Accounts", icon: "bi-diagram-3", path: :chart_of_accounts_path },
        { text: "Journal Voucher", icon: "bi-journal-plus", path: :journal_vouchers_path },
        { text: "Payment Voucher", icon: "bi-arrow-up-circle", path: :payment_vouchers_path },
        { text: "Receipt Voucher", icon: "bi-arrow-down-circle", path: :receipt_vouchers_path },
        { text: "Expenses", icon: "bi-cash", path: :expenses_path },
        { text: "Cash Book", icon: "bi-wallet2", path: :cash_book_path }
      ] },
      { text: "Reports", icon: "bi-bar-chart-line", path: :reports_path },
      { text: "Settings", icon: "bi-gear", key: "settings", children: [
        { text: "Business Settings", icon: "bi-building", path: :business_settings_path },
        { text: "Users", icon: "bi-person-gear", path: :users_path },
        { text: "Branches", icon: "bi-diagram-3", path: :branches_path },
        { text: "Locations", icon: "bi-geo-alt", path: :locations_path },
        { text: "Activity Log", icon: "bi-clock-history", path: :audit_logs_path }
      ] }
    ] }
  ].freeze

  # The sidebar is filtered by the same permission matrix the controllers
  # enforce, so nobody is shown a link that would bounce them.
  def nav_sections
    return [] if current_user&.customer_portal?

    @nav_sections ||= NAV_SECTIONS.filter_map do |section|
      if section[:items]
        items = section[:items].filter_map { |item| filter_nav_item(item) }.presence
        section.merge(items: items) if items
      elsif nav_group_visible?(section)
        section
      end
    end
  end

  # A collapsed group (Products, Transactions, ...) only shows when at least one
  # of its children is allowed.
  def nav_group_visible?(section)
    keys = Array(section[:keys]).map(&:to_s)
    return true if keys.empty?

    keys.any? do |key|
      NAV_SECTIONS.flat_map { |s| Array(s[:items]) }
                 .any? { |item| item[:key].to_s == key && nav_item_visible?(item) }
    end
  end

  def filter_nav_item(item)
    return nil unless nav_item_visible?(item)

    if item[:children]
      children = item[:children].filter_map { |child| nav_item_visible?(child) ? child : nil }
      return nil if children.empty?

      item.merge(children: children)
    else
      item
    end
  end

  def nav_item_visible?(item)
    return item[:children].any? { |child| nav_item_visible?(child) } if item[:children]

    required = item[:permission] || Permissions::NAV_PERMISSIONS[item[:path]]
    (required.blank? || can?(required)) &&
      (item[:path].nil? || permitted_destination?(nav_path(item[:path])))
  end

  def nav_link_class(item)
    classes = ["nav-link"]
    classes << "nav-link-collapse" if item[:children]
    classes << "open" if item[:children] && nav_group_open?(item)
    classes
  end

  def collapse_class(item)
    classes = ["collapse"]
    classes << "show" if item[:children] && nav_group_open?(item)
    classes.join(" ")
  end

  # A group is open when the current page belongs to it, or when the capture
  # had it expanded and the user has not collapsed it in this session.
  def nav_group_open?(item)
    return false unless item[:children]

    current_section == item[:key] || session[:open_nav_groups].to_a.include?(item[:key])
  end

  # Several screens have both a RESTful path (/sales) and a captured-style
  # alias (/sales-list). Highlight by controller#action so the menu stays
  # correct whichever URL the user lands on.
  def nav_active?(item)
    return false unless item[:path]

    target = route_signature(nav_path(item[:path]))
    target.present? && route_signature(request.path) == target
  end

  def route_signature(path)
    @route_signatures ||= {}
    return @route_signatures[path] if @route_signatures.key?(path)

    @route_signatures[path] = begin
      info = Rails.application.routes.recognize_path(path, method: :get)
      "#{info[:controller]}##{info[:action]}"
    rescue ActionController::RoutingError
      nil
    end
  end

  def nav_path(name)
    Rails.application.routes.url_helpers.public_send(name)
  rescue NoMethodError
    "#"
  end

  # ---------------------------------------------------------- phone tab bar
  # The five destinations of the bottom tab bar. They run through the same
  # permission and owner-open-shop filter as the sidebar, so nobody is shown a
  # tab that would only bounce them back to the access-denied page.
  TAB_BAR_ITEMS = [
    { text: "Home", icon: "bi-house-door", path: :root_path, permission: "dashboard.view" },
    { text: "Sales", icon: "bi-receipt", path: :sales_path, permission: "sales.view" },
    { text: "Customers", icon: "bi-people", path: :customers_path, permission: "customers.view" },
    { text: "Collect", icon: "bi-wallet2", path: :installment_collections_path,
      permission: "installments.collect" },
    { text: "Menu", icon: "bi-grid-3x3-gap", path: :more_menu_path, permission: "dashboard.view" }
  ].freeze

  def tab_bar_items
    TAB_BAR_ITEMS.select { |item| nav_item_visible?(item) }
  end

  # A tab is highlighted for every screen of its module, not only its index
  # page: opening a sale keeps the Sales tab lit the way a native tab bar does.
  def tab_active?(item)
    info = Rails.application.routes.recognize_path(nav_path(item[:path]), method: :get)
    info[:controller] == controller_path
  rescue ActionController::RoutingError
    false
  end

  def current_section
    controller_name.to_s
  end

  include MoneyFormat

  def qm_date(date, format: "%d %b %Y")
    return "—" if date.blank?

    date.to_date.strftime(format)
  end

  def status_badge(status)
    css = case status.to_s
    when "paid", "completed", "cleared", "accepted", "converted", "active", "delivered", "sold"
      "success"
    when "partial", "pending", "draft", "sent", "reserved", "confirmed"
      "warning"
    when "cancelled", "returned", "bounced", "rejected", "locked", "inactive"
      "danger"
    when "overdue", "deposited", "short"
      "info"
    else
      "secondary"
    end

    tag.span(status.to_s.humanize.downcase, class: "badge bg-#{css}")
  end

  # Filter and form collections are declared as lambdas in controllers; they are
  # evaluated here so the view context (and its helpers) is available.
  def resolve_options(options)
    options.respond_to?(:call) ? instance_exec(&options) : options
  end

  # Per-document-type state used by the vehicle document list ("Letter",
  # "Warranty Book" columns in the captured design).
  def document_state(sale, type)
    document = sale.vehicle_documents.where(document_type: type).first
    return tag.span("Not tracked", class: "text-muted") if document.nil?
    return status_badge("received") if document.received?
    status_badge("pending")
  end

  def commission_rate(agent)
    if agent.commission_type == "fixed"
      money(agent.commission_amount)
    else
      "#{number_to_percentage(agent.commission_amount.to_d, precision: 2)}"
    end
  end

  def page_header(title, subtitle: nil, icon: "bi-speedometer2", &block)
    # The native shell shows this in its navigation bar, and the browser uses
    # it as the document title, so every screen that declares a header gets a
    # real title without repeating itself in each view.
    content_for(:title, title) unless content_for?(:title)

    heading = tag.div do
      tag.h4(class: "mb-0") { safe_join([tag.i(nil, class: "#{icon} me-2 ph-icon"), title]) } +
        (subtitle.present? ? tag.p(subtitle, class: "text-muted small mb-0") : "".html_safe)
    end

    tag.div(class: "page-header") do
      # Screens with nothing to place beside the heading call this without a
      # block; capture(&nil) would raise, so the slot is simply left empty.
      safe_join([heading, block ? capture(&block) : "".html_safe])
    end
  end

  # The sign-in screen is shared by every shop, so it never brands itself with
  # one tenant's name. A shop may be named explicitly with ?shop=<slug>.
  def platform_brand_name
    slug = params[:shop].presence
    return Business.find_by(slug: slug.to_s.downcase)&.name if slug

    "QistManager"
  end

  def flash_class(level)
    case level.to_s
    when "notice", "success" then "alert-success"
    when "alert", "error" then "alert-danger"
    else "alert-info"
    end
  end

  def plural_count(count)
    "#{count} record#{'s' unless count == 1}"
  end

  # These read the CrudController class attributes when the current controller
  # declares them, and fall back to the request otherwise.
  def crud_config(name)
    klass = controller.class
    klass.respond_to?(name) ? klass.public_send(name) : nil
  end

  def page_title
    crud_config(:page_title) || "QistManager"
  end

  # Document <title>: the screen's own title (set by page_header or
  # content_for :title) with the product name, used by both layouts.
  def document_title
    title = (content_for?(:title) ? content_for(:title) : page_title).to_s.strip
    return "QistManager" if title.blank? || title == "QistManager"

    "#{title} - QistManager"
  end

  def page_subtitle
    crud_config(:page_subtitle)
  end

  def page_icon
    crud_config(:page_icon) || "bi-speedometer2"
  end

  def search_form(action, placeholder: "Search", param: :q, fields: {})
    hidden = fields.map { |name, value| hidden_field_tag(name, value) }.join("").html_safe

    form_tag(action, method: :get, class: "d-flex gap-2 flex-wrap qm-toolbar qm-search-form") do
      safe_join([
        hidden,
        text_field_tag(param, params[param], class: "form-control form-control-sm qm-search",
                                        placeholder: placeholder),
        submit_tag("Search", class: "btn btn-sm btn-outline-secondary", name: nil)
      ])
    end
  end
end

module PermissionControlsHelper
  # Read controller declarations so navigation, actions and the server share
  # permission rules. Route recognition also covers aliases and nested paths.
  def permitted_destination?(destination, method: :get)
    path = url_for(destination)
    uri = URI.parse(path)
    return true if path.start_with?("#") || (uri.host && uri.host != request.host)
    return true if uri.scheme && !%w[http https].include?(uri.scheme)

    @destination_permissions ||= {}
    key = [uri.path, method.to_s.downcase]
    return @destination_permissions[key] if @destination_permissions.key?(key)

    route = Rails.application.routes.recognize_path(uri.path, method: method)
    controller_name = route.fetch(:controller)
    action = route.fetch(:action)
    klass = "#{controller_name.camelize}Controller".constantize

    allowed = if controller_name == "owner"
      current_user&.owner?
    elsif current_user&.customer_portal?
      %w[customer_portal sessions passwords access_denied].include?(controller_name)
    elsif controller_name == "customer_portal"
      false
    elsif klass.shop_admin_action?(action) && !shop_admin? && !(owner? && acting_shop?)
      # Shop-admin-only screens need a business: the owner reaches them as soon
      # as a shop is open, otherwise the owner console is offered instead.
      false
    elsif owner? && !acting_shop? && !ApplicationController::OWNER_WRITE_CONTROLLERS.include?(controller_name) &&
          (!%w[get head].include?(method.to_s.downcase) || %w[new edit].include?(action))
      # Platform view (no shop open): read-only, so create/edit controls stay
      # hidden until the owner opens a shop.
      false
    else
      required = klass.permissions_for_action(action)
      required.blank? || can_any?(*Array(required))
    end
    @destination_permissions[key] = !!allowed
  rescue ActionController::RoutingError, URI::InvalidURIError
    false
  end

  def permitted_link_to(name = nil, options = nil, html_options = nil, &block)
    destination = block ? name : options
    attributes = (block ? options : html_options) || {}
    method = attributes[:method] || attributes.dig(:data, :turbo_method) || :get
    if permitted_destination?(destination, method: method)
      link_to(name, options, html_options, &block)
    elsif !block && !attributes[:class].to_s.split.include?("btn") && !attributes[:class].to_s.split.include?("dropdown-item")
      # Keep customer names and document numbers readable without a link.
      ERB::Util.html_escape(name)
    else
      "".html_safe
    end
  end

  def permitted_button_to(name = nil, options = nil, html_options = nil, &block)
    destination = block ? name : options
    attributes = (block ? options : html_options) || {}
    return "".html_safe unless permitted_destination?(destination, method: attributes[:method] || :post)

    button_to(name, options, html_options, &block)
  end

  def permitted_form_with(model: false, url: nil, **options, &block)
    record = model ? convert_to_model(model) : nil
    destination = url || (record && polymorphic_path(record))
    method = options[:method] || (record&.persisted? ? :patch : :post)
    return "".html_safe unless permitted_destination?(destination, method: method)

    # form_with treats an explicit nil model as an error, so only pass it when
    # the form really is bound to a record.
    form_with(**{ model: model }.compact, url: url, **options, &block)
  end
end

# Declarative per-action permission guards:
#
#   guard index: "sales.view", new: "sales.create"
#   guard index: %w[installments.view installments.collect]
#
# A guard runs before the action; a `nil` permission means "no check".
module PermissionGuards
  extend ActiveSupport::Concern

  class_methods do
    def shop_admin_only(*actions)
      @shop_admin_actions = actions.map(&:to_s)
      before_action :require_shop_admin!, only: actions unless actions.empty?
      before_action :require_shop_admin! if actions.empty?
    end

    def shop_admin_action?(action)
      defined?(@shop_admin_actions) && (@shop_admin_actions.empty? || @shop_admin_actions.include?(action.to_s))
    end

    def guard(mapping = {})
      @permission_guards = (permission_guards || {}).merge(mapping.symbolize_keys)
      before_action(:enforce_permission_guards!) unless @permission_guards_installed
      @permission_guards_installed = true
    end

    def permission_guards
      @permission_guards ||= superclass.respond_to?(:permission_guards) ? superclass.permission_guards.dup : {}
    end

    def permissions_for_action(action)
      permission_guards[action.to_sym] || permission_guards[:all]
    end
  end

  def enforce_permission_guards!
    required = self.class.permissions_for_action(action_name)
    return true if required.nil?

    required = [required] unless required.is_a?(Array)
    authorize_any!(*required)
  end
end

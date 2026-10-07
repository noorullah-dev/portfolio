# Request-scoped context for the whole application.
#
# Deliberately backed by IsolatedExecutionState rather than
# ActiveSupport::CurrentAttributes: the app runs nested in-process integration
# harnesses (script/smoke_*.rb) where the CurrentAttributes registry does not
# survive the executor reset, and the context has to be explicitly set and
# cleared by the controller instead.
#
# * owner?      -> platform super admin: sees every shop until they open one
# * business_id -> the tenant the signed-in user belongs to (or the shop the
#                  owner has opened through the owner console)
# * branch_id   -> the user's branch (nil for shop admins and the owner)
# * scope       -> "business" (shop-wide) or "branch"
# * location_ids-> the locations a recovery officer is allowed to work in
# * acting      -> the owner opened a shop, so the context is that shop alone
module Current
  KEY = :qistmanager_current

  EMPTY = {
    user: nil,
    business_id: nil,
    branch_id: nil,
    permissions_scope: nil,
    location_ids: [],
    bypass: false,
    acting: false
  }.freeze

  class << self
    def attributes
      ActiveSupport::IsolatedExecutionState[KEY] ||= EMPTY.dup
    end

    def reset!
      ActiveSupport::IsolatedExecutionState[KEY] = EMPTY.dup
      self
    end

    # Stores identifiers only: loading the business/branch associations on every
    # request would add two queries before the controller has even run.
    def set_from(user)
      return reset! if user.nil?

      ActiveSupport::IsolatedExecutionState[KEY] = {
        user: user,
        business_id: user.business_id,
        branch_id: user.branch_id,
        permissions_scope: user.permissions_scope,
        location_ids: user.recovery_officer? ? user.assigned_location_ids : [],
        bypass: false,
        acting: false
      }
      self
    end

    # The platform owner has no shop of their own. Opening one from the owner
    # console narrows the context to that shop alone, which is what lets the
    # owner run every shop action (create, edit, delete, administer staff)
    # under the exact same tenant rules as the shop's own staff.
    def act_as(business)
      return self if business.nil?

      attributes[:business_id] = business.id
      attributes[:branch_id] = nil
      attributes[:permissions_scope] = "business"
      attributes[:acting] = true
      self
    end

    def user = attributes[:user]
    def business_id = attributes[:business_id]
    def branch_id = attributes[:branch_id]
    def permissions_scope = attributes[:permissions_scope]
    def location_ids = attributes[:location_ids]
    def bypass? = !!attributes[:bypass]

    def business
      business_id && Business.find_by(id: business_id)
    end

    def branch
      branch_id && Branch.find_by(id: branch_id)
    end

    def bypass!
      attributes[:bypass] = true
      self
    end

    def reset_all = reset!

    def owner? = user.present? && user.owner?

    def customer_portal? = user.present? && user.customer_portal?

    # Shop admins (and the owner) see every branch of their shop; everyone else
    # is limited to their own branch.
    def all_branches? = permissions_scope.to_s == "business"

    def location_restricted? = user.present? && user.location_scoped?

    # A recovery officer with no assignments may not see any location at all.
    def location_ids
      ids = attributes[:location_ids]
      return ids if ids.present?

      user&.location_scoped? ? [] : ids
    end

    # True when the context may look across the whole platform. The owner has
    # that view until they open a shop; from then on they are scoped to it like
    # any other shop-wide user, so they can never edit one shop's data while
    # another shop's rows are loaded.
    def cross_tenant? = bypass? || (owner? && !acting?)

    # True while the owner is working inside a shop opened from the console.
    def acting? = !!attributes[:acting]

    def acting_business_id = acting? ? business_id : nil

    def can?(permission) = user.present? && user.can?(permission)

    # Builds the tenant filter for a model, failing closed when there is no
    # tenant context (a query can never accidentally return another shop's rows).
    def tenant_scope(model)
      return model.all if cross_tenant?

      return model.all unless model.column_names.include?("business_id")
      return model.none if business_id.nil?

      scope = model.where(business_id: business_id)
      if !all_branches? && model.table_name == "branches"
        return branch_id ? scope.where(id: branch_id) : model.none
      end
      # Shop-wide reference data (customers, brands, categories, parties,
      # accounts) is shared by every branch, so the branch filter is skipped.
      branch_scoped = !model.respond_to?(:tenant_branch_scoped) || model.tenant_branch_scoped
      if branch_scoped && !all_branches? && model.column_names.include?("branch_id")
        return model.none unless branch_id

        scope = scope.where(branch_id: branch_id)
      end
      scope = apply_location_scope(scope, model)
      scope
    end

    # Recovery officers are limited to the locations assigned to them, and to
    # nothing at all when they have no assignment (fails closed).
    def apply_location_scope(scope, model)
      return scope unless location_restricted?
      return scope unless model.respond_to?(:tenant_location_scoped) && model.tenant_location_scoped

      column = model.respond_to?(:tenant_location_column) ? model.tenant_location_column : :location_id
      through = model.respond_to?(:tenant_location_through) ? model.tenant_location_through : nil
      via = model.respond_to?(:tenant_location_via) ? model.tenant_location_via : nil

      return scope.where(column => location_ids) if through.blank? || via.blank?

      # e.g. sales, instalments and recoveries are reachable through the
      # customer's location. When the parent is location scoped as well the
      # chain composes: Sale.shop is already limited to the officer's locations.
      parent = via.constantize
      parent = parent.respond_to?(:shop) ? parent.shop : parent.where(location_id: location_ids)
      scope.where(through => parent.select(parent.primary_key))
    end

    # Same as tenant_scope but ignoring the branch restriction - used by the
    # shop admin's roll-up screens.
    def business_scope(model)
      return model.all if cross_tenant?
      return model.all unless model.column_names.include?("business_id")

      business_id ? model.where(business_id: business_id) : model.none
    end

    def audit!(action, record: nil, summary: nil, changes: {}, request: nil, subject_user: nil)
      AuditLog.write!(
        action: action,
        record: record,
        summary: summary,
        changes: changes,
        request: request,
        subject_user: subject_user
      )
    end
  end
end

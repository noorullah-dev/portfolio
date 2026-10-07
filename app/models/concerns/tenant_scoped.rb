# Fails closed unless the context is explicitly widened.
#
# Usage inside a class body:
#   scope :shop, -> { Current.tenant_scope(self) }
#
# Read isolation is explicit (controllers must go through `Model.shop`), while
# write stamping is automatic: every new row picks up the signed-in shop and
# branch, so a forgotten `business_id` can never write into another tenant.
module TenantScoped
  extend ActiveSupport::Concern

  included do
    before_validation :stamp_tenant_columns, on: :create

    # Shop-wide reference data: a single brand/catalogue/account is shared by
    # every branch of the business, so it is stamped with the business only.
    class_attribute :tenant_branch_scoped, instance_writer: false, default: true

    # Location restricted data: recovery officers only ever see the locations
    # they were assigned to. Off by default, switched on with location_scoped!.
    class_attribute :tenant_location_scoped, instance_writer: false, default: false
    class_attribute :tenant_location_column, instance_writer: false, default: :location_id
    class_attribute :tenant_location_through, instance_writer: false, default: nil
    class_attribute :tenant_location_via, instance_writer: false, default: nil
  end

  class_methods do
    # Every query in the app funnels through these, so a user can never read
    # another shop's rows by accident.
    def shop
      Current.tenant_scope(self)
    end

    def shop_wide
      Current.business_scope(self)
    end

    def platform
      Current.cross_tenant? ? all : Current.tenant_scope(self)
    end

    def shop_wide_reference_data!
      self.tenant_branch_scoped = false
    end

    # A location restricted model is filtered by the recovery officer's
    # assignments. Location itself filters on id, customer-owned rows on
    # location_id, and rows that only know their customer through a foreign key
    # (sales, instalments, recoveries) through that column:
    #
    #   location_scoped!
    #   location_scoped!(column: :id)
    #   location_scoped!(through: :customer_id, via: "Customer")
    def location_scoped!(column: :location_id, through: nil, via: nil)
      self.tenant_location_scoped = true
      self.tenant_location_column = column
      self.tenant_location_through = through
      self.tenant_location_via = via
    end
  end

  private

  # The signed-in shop always wins over whatever a request or console supplied,
  # so a crafted business_id/branch_id can never write into another tenant. The
  # platform owner has no business of its own and is the only context allowed to
  # place a row for more than one shop.
  def stamp_tenant_columns
    return if Current.user.nil?
    return unless has_attribute?(:business_id)

    if Current.cross_tenant?
      self.business_id = Current.business_id if Current.business_id
      self.branch_id = Current.branch_id if has_attribute?(:branch_id) && tenant_branch_scoped && Current.branch_id
      return
    end

    if Current.business_id
      if business_id.present? && business_id != Current.business_id
        errors.add(:business_id, "cannot be set outside your own shop")
      else
        self.business_id = Current.business_id
      end
    end

    return unless tenant_branch_scoped && has_attribute?(:branch_id)

    if Current.all_branches?
      # A shop admin works across every branch of the shop, so any of their own
      # branches is acceptable - but a branch from another shop never is.
      return if branch_id.blank?
      return if Branch.exists?(id: branch_id, business_id: Current.business_id)

      errors.add(:branch_id, "must belong to your own shop")
    elsif Current.branch_id
      if branch_id.present? && branch_id != Current.branch_id
        errors.add(:branch_id, "cannot be set outside your own branch")
      else
        self.branch_id = Current.branch_id
      end
    end
  end
end
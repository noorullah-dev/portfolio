# Append-only trail of sensitive actions. Written by services/controllers and by
# the model callbacks listed in AUDITED_EVENTS below.
class AuditLog < ApplicationRecord
  belongs_to :business, optional: true
  belongs_to :branch, optional: true
  belongs_to :user, optional: true
  belongs_to :subject_user, class_name: "User", optional: true

  # Keep the trail bounded; older rows can be pruned by a scheduled task.
  MAX_ROWS = 200_000

  IGNORED_CHANGES = %w[updated_at lockout_expires_at locked_until failed_login_count
                       last_login_at password_digest must_change_password].freeze

  class << self
    def write!(action:, record: nil, summary: nil, changes: {}, request: nil, subject_user: nil)
      create!(
        business_id: record&.respond_to?(:business_id) ? record.business_id : Current.business_id,
        branch_id: record&.respond_to?(:branch_id) ? record.branch_id : Current.branch_id,
        user_id: Current.user&.id,
        role: Current.user&.role,
        action: action.to_s,
        record_type: record&.class&.name,
        record_id: record&.id,
        subject_user_id: subject_user&.id,
        summary: summary.presence || default_summary(action, record),
        detail: sanitize(changes),
        request_method: request&.request_method,
        request_path: request&.fullpath&.truncate(255),
        ip_address: request&.remote_ip
      )
    rescue ActiveRecord::ActiveRecordError
      # An audit failure must never break the business operation.
      nil
    end

    def for_tenant
      Current.tenant_scope(self)
    end

    def recent(limit = 100)
      for_tenant.order(created_at: :desc, id: :desc).limit(limit)
    end

    def prune!
      cutoff = order(created_at: :desc).offset(MAX_ROWS).limit(1).pick(:created_at)
      cutoff ? where(created_at: ...cutoff).delete_all : 0
    end

    private

    def sanitize(changes)
      return {} if changes.blank?
      return {} unless changes.is_a?(Hash)

      changes.except(*IGNORED_CHANGES)
             .transform_values { |v| truncate_value(v) }
    end

    def truncate_value(value)
      case value
      when Hash  then value.transform_values { |v| truncate_value(v) }
      when Array then value.first(10).map { |v| truncate_value(v) }
      when String then value.truncate(200)
      else value
      end
    end

    def default_summary(action, record)
      return action.to_s.tr(".", " ").capitalize if record.nil?

      "#{action.to_s.tr('.', ' ').capitalize} #{record.class.name.underscore.humanize.downcase} ##{record.id}"
    end
  end
end

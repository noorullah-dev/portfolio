# "changes" is reserved by ActiveRecord (Dirty Tracking) - assigning it raises
# DangerousAttributeError, so every audit write was being swallowed by the
# rescue in AuditLog.write!.
class RenameAuditLogChanges < ActiveRecord::Migration[8.1]
  def change
    rename_column :audit_logs, :changes, :detail unless column_exists?(:audit_logs, :detail)
  end
end

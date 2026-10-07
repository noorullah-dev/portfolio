# Read-only activity trail for shop admins and the platform owner.
class AuditLogsController < ApplicationController
  guard all: "audit.view"

  before_action :require_admin!
  before_action :set_log, only: :show

  def index
    @logs = AuditLog.for_tenant
    @logs = @logs.where(user_id: params[:user_id]) if params[:user_id].present?
    @logs = @logs.where(action: params[:q]) if params[:q].present?
    @logs = @logs.where(record_type: params[:record_type]) if params[:record_type].present?
    @logs = @logs.order(created_at: :desc, id: :desc).limit(300)
  end

  def show; end

  private

  def set_log
    @log = AuditLog.for_tenant.find(params[:id])
  end
end

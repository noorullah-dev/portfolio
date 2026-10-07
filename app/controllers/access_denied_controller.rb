# Friendly 403 page. Controllers redirect here instead of rendering a raw
# forbidden, and the refusal itself is written to the audit log.
class AccessDeniedController < ApplicationController
  skip_before_action :enforce_portal_user

  def show
    @attempted = params[:from].presence || request.env["HTTP_REFERER"].to_s
    respond_to do |format|
      format.html { render :show, status: :forbidden }
      format.any { head :forbidden }
    end
  end
end

class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]
  skip_before_action :enforce_portal_user, only: %i[new create]
  layout "auth"

  def new
    redirect_to landing_path if signed_in?
  end

  def create
    user = User.authenticate(params[:username], params[:password])

    if user
      sign_in(user)
      # A portal login never lands in the staff application, and a forced
      # password change always comes next.
      redirect_back_or(landing_path)
    else
      flash.now[:alert] = invalid_credentials_message
      @username = params[:username]
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to login_path, notice: "You have been signed out."
  end

  private

  # Where a freshly signed-in user belongs.
  def landing_path
    return change_password_path if current_user&.must_change_password?
    return customer_portal_path if current_user&.customer_portal?
    return owner_businesses_path if current_user&.owner?

    root_path
  end

  def invalid_credentials_message
    if params[:password].blank?
      "Please enter your password."
    else
      "Invalid username or password."
    end
  end
end
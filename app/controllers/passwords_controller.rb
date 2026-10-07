class PasswordsController < ApplicationController
  before_action :set_user
  # A user flagged must_change_password cannot use the app until it is changed.
  before_action :force_password_change!

  def edit; end

  def update
    if params[:current_password].present? && !@user.authenticate(params[:current_password])
      flash.now[:alert] = "Your current password is not correct."
      return render :edit, status: :unprocessable_entity
    end

    if params[:password].blank?
      flash.now[:alert] = "Please type a new password."
      return render :edit, status: :unprocessable_entity
    end

    @user.password = params[:password]
    @user.password_confirmation = params[:password_confirmation]
    @user.must_change_password = false

    if @user.save
      sign_in(@user)
      Current.audit!(:"user.password_change", record: @user,
                                            summary: "#{@user.username} changed their password")
      redirect_to password_changed_landing_path, notice: "Your password has been changed."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def force_password_change!
    return unless current_user&.must_change_password?
    return if controller_name == "passwords" && action_name.in?(%w[edit update])

    redirect_to change_password_path, alert: "Please set a new password before continuing."
  end

  def password_changed_landing_path
    return customer_portal_path if current_user.customer_portal?
    return owner_businesses_path if current_user.owner?

    root_path
  end

  def set_user
    @user = current_user
    redirect_to login_path, alert: "Please sign in first." if @user.nil?
  end
end
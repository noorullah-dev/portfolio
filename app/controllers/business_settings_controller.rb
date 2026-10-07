require "fileutils"

class BusinessSettingsController < ApplicationController

  guard all: "settings.edit"
  before_action :require_admin!
  before_action :set_business

  def edit
    @payment_modes = PaymentMode.shop.order(:id)
    @branches = Branch.shop.ordered
    @locations = Location.shop.ordered
  end

  def update
    return require_open_shop!("change company settings") if owner?

    @business.assign_attributes(business_params)
    logo = params.dig(:business, :logo)
    @business.logo_filename = store_logo(logo) if logo.present?

    if @business.save
      redirect_to business_settings_path, notice: "Business settings saved."
    else
      @payment_modes = PaymentMode.shop.order(:id)
      @branches = Branch.shop.ordered
      @locations = Location.shop.ordered
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Shop settings are always the signed-in user's own shop; the platform owner
  # is read-only and cannot edit a shop's settings.
  def set_business
    @business = business || overseen_business
    return if @business.present?

    redirect_to root_path, alert: "No company is selected."
  end

  # The captured screen uploaded the logo straight to the uploads folder.
  def store_logo(file)
    return nil unless file.respond_to?(:original_filename)

    name = file.original_filename.to_s.gsub(/[^a-zA-Z0-9._-]/, "_")
    return nil if name.blank?

    dir = Rails.public_path.join("uploads")
    FileUtils.mkdir_p(dir)
    File.binwrite(dir.join(name), file.read)
    name
  end

  def business_params
    params.require(:business).permit(:name, :business_type, :phone, :email, :address, :city, :cnic, :ntn,
                                      :currency, :footer_text, :default_installment_day, :late_fee_type,
                                      :late_fee_amount, :low_stock_alert, :allow_negative_stock)
  end
end
# Locations group customers geographically and are the unit a recovery officer is
# assigned to.
class LocationsController < ApplicationController
  guard index: "branches.view", show: "branches.view",
        new: "branches.create", create: "branches.create",
        edit: "branches.edit", update: "branches.edit",
        destroy: "branches.delete"

  shop_admin_only :new, :create, :edit, :update, :destroy
  before_action :set_location, only: %i[show edit update destroy]
  before_action :ensure_own_tenant!, only: %i[show edit update destroy]

  def index
    @locations = Location.shop.ordered.map do |location|
      { location: location, customers: location.customer_count, officers: location.officers.count }
    end
  end

  def show
    @customers = @location.customers.order(:name)
    @officers = @location.officers
  end

  def new
    @location = Location.new(business_id: business&.id, status: "active")
  end

  def create
    @location = Location.new(location_params.merge(business_id: business&.id))
    if @location.save
      Current.audit!(:"location.create", record: @location, summary: "Created location #{@location.name}")
      redirect_to locations_path, notice: "Location #{@location.name} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @location.update(location_params)
      Current.audit!(:"location.update", record: @location, summary: "Updated location #{@location.name}")
      redirect_to locations_path, notice: "Location updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @location.customers.exists?
      redirect_to locations_path, alert: "Move the customers of this location before deleting it."
    else
      name = @location.name
      @location.destroy
      Current.audit!(:"location.delete", summary: "Deleted location #{name}")
      redirect_to locations_path, notice: "Location #{name} deleted."
    end
  end

  private

  def set_location
    @location = Location.shop.find(params[:id])
  end

  def ensure_own_tenant!
    return if owner? || @location.business_id == business&.id

    redirect_to locations_path, alert: "That location belongs to another company."
  end

  def location_params
    params.require(:location).permit(:name, :city, :zone, :status)
  end
end

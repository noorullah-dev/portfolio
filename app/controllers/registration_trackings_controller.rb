class RegistrationTrackingsController < ApplicationController

  guard index: "registration.view", show: "registration.view", new: "registration.manage", create: "registration.manage", edit: "registration.manage", update: "registration.manage", destroy: "registration.manage"
  before_action :set_sale, only: %i[new create show]
  before_action :set_tracking, only: %i[edit update destroy]

  def index
    @trackings = RegistrationTracking.shop.includes(:sale, :created_by).order(updated_at: :desc)
    @trackings = @trackings.where(status: params[:status]) if params[:status].present?
  end

  def new
    @tracking = @sale.registration_tracking || @sale.build_registration_tracking(
      customer: @sale.customer,
      engine_no: @sale.stock_unit&.engine_no,
      chassis_no: @sale.stock_unit&.chassis_no,
      agent_id: @sale.agent_id,
      submitted_date: Date.current,
      expected_return_date: 30.days.from_now.to_date
    )
  end

  def create
    @tracking = @sale.build_registration_tracking(
      tracking_params.merge(customer_id: @sale.customer_id, created_by: current_user)
    )

    if @tracking.save
      redirect_to sale_registration_tracking_path(@sale), notice: "Registration tracking started."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @tracking ||= @sale.registration_tracking || @sale.build_registration_tracking(
      customer: @sale.customer,
      engine_no: @sale.stock_unit&.engine_no,
      chassis_no: @sale.stock_unit&.chassis_no,
      agent_id: @sale.agent_id,
      submitted_date: Date.current,
      expected_return_date: 30.days.from_now.to_date
    )
    @sale = @tracking.sale
  end

  def edit
    render :new
  end

  def update
    if @tracking.update(tracking_params)
      redirect_to sale_registration_tracking_path(@tracking.sale), notice: "Tracking updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    sale = @tracking.sale
    @tracking.destroy
    redirect_to(sale ? sale_path(sale) : registration_trackings_path, notice: "Tracking removed.")
  end

  private

  def set_sale
    @sale = Sale.shop.find(params[:sale_id])
  end

  def set_tracking
    @tracking = RegistrationTracking.shop.find(params[:id])
    @sale = @tracking.sale
  end

  def tracking_params
    params.require(:registration_tracking).permit(:status, :submitted_date, :expected_return_date,
                                                   :letter_received, :received_date, :remarks)
  end
end
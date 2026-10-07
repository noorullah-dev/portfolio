class AdvanceBookingsController < ApplicationController

  guard index: "bookings.view", show: "bookings.view", new: "bookings.create", create: "bookings.create", edit: "bookings.edit", update: "bookings.edit", destroy: "bookings.delete", collect_payment: "bookings.collect"
  before_action :set_booking, only: %i[show edit update destroy]

  def index
    @bookings = AdvanceBooking.shop.includes(:customer, :product, :variant, :stock_unit, :agent)
    @bookings = @bookings.where(status: params[:status]) if params[:status].present?
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      @bookings = @bookings.where("booking_no ILIKE :q OR customer_name ILIKE :q OR customer_phone ILIKE :q", q: term)
    end
    @bookings = paginate(@bookings.recent, per_page: 25)

    @summary = {
      confirmed: AdvanceBooking.shop.active_bookings.count,
      advance: AdvanceBooking.shop.sum(:advance_amount),
      receivable: AdvanceBooking.shop.sum(:balance_amount)
    }
  end

  def show
    @payments = @booking.payments.recent.includes(:payment_mode)
    @plans = @booking.plans.order(:installment_no)
  end

  def new
    @booking = AdvanceBooking.new(booking_date: Date.current, sale_type: "credit",
                                   months: 12, customer_id: params[:customer_id])
    load_collections
  end

  def create
    @booking = AdvanceBooking.new(booking_params)
    @booking.created_by = current_user
    @booking.customer_name ||= @booking.customer&.name
    @booking.customer_phone ||= @booking.customer&.phone

    if @booking.save
      if @booking.advance_amount.to_d.positive?
        @booking.record_payment!(amount: @booking.advance_amount, payment_date: @booking.booking_date,
                                 payment_mode: PaymentMode.shop.first, created_by: current_user,
                                 remarks: "Advance received with booking")
      end
      redirect_to advance_booking_path(@booking), notice: "Booking #{@booking.booking_no} created."
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_collections
  end

  def update
    if @booking.update(booking_params)
      redirect_to advance_booking_path(@booking), notice: "Booking #{@booking.booking_no} updated."
    else
      load_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @booking.destroy
    redirect_to advance_bookings_path, notice: "Booking deleted."
  end

  private

  def set_booking
    @booking = AdvanceBooking.shop.find(params[:id])
  end

  def load_collections
    @customers = Customer.shop.active.order(:name)
    @products = Product.shop.active.includes(:variants).order(:name)
    @stock_units = StockUnit.shop.available.includes(:product, :variant)
    @agents = Agent.shop.active.order(:name)
  end

  def booking_params
    params.require(:advance_booking).permit(:booking_date, :customer_id, :product_id, :variant_id, :stock_unit_id,
                                            :sale_type, :total_amount, :advance_amount, :months, :expected_delivery,
                                            :late_fee_type, :agent_id, :status, :remarks)
  end
end
class AdvanceBookingPaymentsController < ApplicationController

  guard all: "bookings.collect"
  before_action :set_booking

  def create
    payment = @booking.record_payment!(
      amount: params[:amount],
      payment_date: params[:payment_date].presence || Date.current,
      payment_mode: PaymentMode.shop.find_by(id: params[:payment_mode_id]),
      remarks: params[:remarks].presence,
      created_by: current_user
    )

    redirect_to advance_booking_path(@booking), notice: "Payment of #{money(payment.amount)} recorded."
  rescue ArgumentError => e
    redirect_to advance_booking_path(@booking), alert: e.message
  end

  private

  def set_booking
    @booking = AdvanceBooking.shop.find(params[:advance_booking_id])
  end
end
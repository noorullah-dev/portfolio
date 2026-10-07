class PurchasePaymentsController < ApplicationController

  guard all: "purchases.pay"
  before_action :set_purchase

  def create
    payment = @purchase.record_payment!(
      amount: params[:amount],
      payment_date: params[:payment_date].presence || Date.current,
      payment_mode: PaymentMode.shop.find_by(id: params[:payment_mode_id]),
      reference: params[:reference].presence,
      remarks: params[:remarks].presence,
      created_by: current_user
    )

    redirect_to purchase_path(@purchase), notice: "Payment of #{money(payment.amount)} recorded."
  rescue ArgumentError => e
    redirect_to purchase_path(@purchase), alert: e.message
  end

  private

  def set_purchase
    @purchase = Purchase.shop.find(params[:purchase_id])
  end
end
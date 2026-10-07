class InstallmentPaymentsController < ApplicationController

  guard index: "installments.view", new: "installments.collect", create: "installments.collect", quick_create: "installments.collect", destroy: "installments.collect"
  before_action :set_sale, only: %i[new create]

  # Nested route: /sales/:sale_id/payments
  def new
    @sale = Sale.shop.find(params[:sale_id])
    @payment = @sale.installment_payments.new(
      payment_date: Date.current,
      payment_mode_id: params[:payment_mode_id]
    )
    load_collections
  end

  # Nested route: POST /sales/:sale_id/payments
  def create
    @sale = Sale.shop.find(params[:sale_id])
    @payment = @sale.installment_payments.new(payment_params)
    @payment.created_by = current_user

    if @payment.save
      redirect_to sale_path(@sale), notice: payment_notice
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  # Top-level quick-collect from the collection screen: POST /installments/collection
  def quick_create
    @sale = Sale.shop.find(params[:sale_id])
    payment = @sale.installment_payments.new(
      amount: params[:amount],
      payment_date: params[:payment_date],
      payment_mode_id: params[:payment_mode_id],
      reference: params[:reference],
      created_by: current_user
    )

    if payment.save
      redirect_to installment_collections_path(customer_id: @sale.customer_id), notice: payment_notice(payment)
    else
      redirect_to installment_collections_path(customer_id: @sale.customer_id,
                                              anchor: "sale_#{@sale.id}"),
                  alert: payment.errors.full_messages.to_sentence
    end
  end

  private

  def set_sale
    @sale = Sale.shop.find(params[:sale_id])
  end

  def load_collections
    @payment_modes = PaymentMode.shop.cash_first
    @plans = @sale.installment_plans.unpaid.chronological
    @sale.reload
  end

  def payment_params
    params.require(:installment_payment).permit(:amount, :payment_date, :payment_mode_id, :reference, :remarks)
  end

  def payment_notice(payment = @payment)
    parts = ["Payment of #{money(payment.amount)} recorded."]
    parts << "Advance balance #{money(payment.advance_amount)}." if payment.advance_amount.to_d.positive?
    parts << "Still short by #{money(payment.short_amount)}." if payment.short_amount.to_d.positive?
    parts.join(" ")
  end
end
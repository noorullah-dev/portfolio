class InstallmentCollectionsController < ApplicationController

  guard index: "installments.view", show: "installments.view", collect: "installments.collect", create: "installments.collect", destroy: "installments.collect"
  def index
    @day = params[:day].present? ? params[:day].to_date : Date.current
    @customers = defaulters_or_all

    if params[:q].present?
      @customers = @customers.where("name ILIKE :q OR account_no ILIKE :q OR phone ILIKE :q", q: "%#{params[:q]}%")
    end

    @collections = scoped_sales.includes(:customer, :installment_plans)
                              .where(customer_id: @customers.map(&:id), status: %w[completed delivered])
                              .order(sale_date: :desc)

    @payment_modes = PaymentMode.shop.cash_first
    @today = installments_for(@day)
    @overdue = installments_for(@day, overdue: true)
    @summary = {
      due_today: @today.count,
      amount_today: @today.sum(&:remaining),
      overdue: @overdue.count,
      overdue_amount: @overdue.sum(&:remaining)
    }
  end

  def create
    sale = Sale.shop.find(params[:sale_id])
    unless location_allowed?(sale.customer&.location_id)
      redirect_to installment_collections_path,
                  alert: "That customer is outside your assigned locations."
      return
    end

    payment = sale.installment_payments.new(
      amount: params[:amount],
      payment_date: params[:payment_date].presence || Date.current,
      payment_mode_id: params[:payment_mode_id],
      reference: params[:reference],
      created_by: current_user
    )

    if payment.save
      redirect_to installment_collections_path(customer_id: sale.customer_id, anchor: "sale_#{sale.id}"),
                  notice: collection_notice(payment)
    else
      redirect_to installment_collections_path(customer_id: sale.customer_id, anchor: "sale_#{sale.id}"),
                  alert: payment.errors.full_messages.to_sentence
    end
  end

  private

  def defaulters_or_all
    scope = Customer.shop.active
    scope = scope.where(location_id: allowed_location_ids) if location_restricted?
    scope = scope.where(id: overdue_customer_ids) if params[:filter].to_s == "overdue"
    scope.order(:name)
  end

  def scoped_sales
    scope = Sale.shop
    scope = scope.where(customer_id: Customer.shop.where(location_id: allowed_location_ids).select(:id)) if location_restricted?
    scope
  end

  def overdue_customer_ids
    scoped_sales.where(status: %w[completed delivered]).joins(:installment_plans)
        .where("installment_plans.status <> 'paid' AND installment_plans.due_date < ?", @day)
        .distinct.pluck("sales.customer_id")
  end

  def installments_for(date, overdue: false)
    scope = InstallmentPlan.shop.includes(sale: :customer)
                                .where.not(status: "paid")
                                .where(sale_id: scoped_sales.where(status: %w[completed delivered]).select(:id))
    scope = overdue ? scope.where(due_date: ...date) : scope.where(due_date: date)
    scope.to_a
  end

  def collection_notice(payment)
    parts = ["Payment of #{money(payment.amount)} recorded for #{payment.sale.sale_no}."]
    parts << "Advance balance #{money(payment.advance_amount)}." if payment.advance_amount.to_d.positive?
    parts << "Still short by #{money(payment.short_amount)}." if payment.short_amount.to_d.positive?
    parts.join(" ")
  end
end
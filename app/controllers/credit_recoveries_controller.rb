class CreditRecoveriesController < ApplicationController

  guard index: "credit_recovery.view", new: "credit_recovery.manage", create: "credit_recovery.manage", update: "credit_recovery.manage", destroy: "credit_recovery.manage"
  before_action :set_recovery, only: %i[destroy]

  def index
    @recoveries = CreditRecovery.shop.includes(:sale, :customer, :payment_mode, :created_by)
    @recoveries = @recoveries.order(recovery_date: :desc, id: :desc)

    @totals = {
      month: CreditRecovery.shop.where(recovery_date: Date.current.beginning_of_month..Date.current).sum(:amount),
      all_time: CreditRecovery.shop.sum(:amount),
      count: CreditRecovery.shop.count
    }

    @defaulters = Customer.shop.active.select { |c| c.defaulter? }

    # Sale-wise recovery plan: every financed sale that still owes money, with
    # the latest agreed date and recovery progress (captured design table).
    @plans = Sale.shop.active_sales.credit.includes(:customer, :stock_unit, :installment_plans)
                .select { |s| s.balance.to_d.positive? }
                .sort_by { |s| -s.overdue_amount }
                .first(50)
    @agreed_dates = CreditRecovery.shop.where(sale_id: @plans.map(&:id)).group(:sale_id).maximum(:agreed_date)
  end

  def new
    @recovery = CreditRecovery.new(recovery_date: Date.current)
    load_collections
  end

  def create
    @recovery = CreditRecovery.new(recovery_params)
    @recovery.created_by = current_user
    @recovery.customer_id ||= @recovery.sale&.customer_id

    if @recovery.save
      payment = @recovery.sale&.installment_payments&.create(
        amount: @recovery.amount,
        payment_date: @recovery.recovery_date,
        payment_mode_id: @recovery.payment_mode_id,
        reference: @recovery.reference,
        remarks: "Recovered: #{@recovery.remarks}",
        created_by: current_user
      )

      redirect_to credit_recoveries_path,
                  notice: "Recovered #{money(@recovery.amount)} from #{@recovery.customer&.display_name}."
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @recovery.destroy
    redirect_to credit_recoveries_path, notice: "Recovery entry deleted."
  end

  private

  def set_recovery
    @recovery = CreditRecovery.shop.find(params[:id])
  end

  def load_collections
    @sales = Sale.shop.includes(:customer)
                  .where(status: %w[completed delivered])
                  .order(sale_date: :desc)
                  .to_a
    @defaulters = @sales.select { |sale| sale.customer&.defaulter? }
    @payment_modes = PaymentMode.shop.cash_first
  end

  def recovery_params
    params.require(:credit_recovery).permit(:sale_id, :recovery_date, :agreed_date, :amount,
                                             :payment_mode_id, :reference, :remarks)
  end
end
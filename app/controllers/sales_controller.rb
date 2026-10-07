class SalesController < ApplicationController

  guard index: "sales.view", show: "sales.view", new: "sales.create", create: "sales.create", edit: "sales.edit", update: "sales.edit", cancel: "sales.cancel", destroy: "sales.delete", payment: "sales.view", add_payment: "sales.view", print: "sales.view", receipt: "sales.view"
  before_action :set_sale, only: %i[show edit update destroy cancel]

  def index
    @sales = Sale.shop.search(params[:q]).recent.includes(:customer, :agent, :payment_mode, :stock_unit)
    @sales = filter_by(@sales)
    @sales = paginate(@sales)
    @total_count = @sales.total_count
  end

  def show
    @plans = @sale.installment_plans.chronological
    @payments = @sale.installment_payments.recent.includes(:payment_mode, :created_by)
    @documents = @sale.vehicle_documents
    @tracking = @sale.registration_tracking
    @cheques = @sale.post_dated_cheques.recent
    @commission = @sale.agent_commissions.first
  end

  rescue_from LedgerPosting::UnbalancedError, with: :render_finance_error

  def new
    @sale = Sale.new(sale_date: Date.current, sale_type: "credit", months: 12)
    @sale.customer_id = params[:customer_id]
    load_form_collections
  end

  def create
    @sale = Sale.new(sale_params)
    @sale.created_by = current_user
    @sale.status = "completed"

    if @sale.save
      redirect_to sale_path(@sale), notice: "Sale #{@sale.sale_no} recorded."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_collections
    render :new
  end

  def update
    @sale.assign_attributes(sale_params)

    if @sale.save
      redirect_to sale_path(@sale), notice: "Sale #{@sale.sale_no} updated."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def render_finance_error(error)
    @sale ||= Sale.new
    @sale.errors.add(:base, error.message)
    load_form_collections
    render :new, status: :unprocessable_entity
  end

  def destroy
    if @sale.cancelled?
      @sale.destroy
      redirect_to sales_path, notice: "Sale deleted."
    else
      redirect_to sale_path(@sale), alert: "Cancel the sale before deleting it."
    end
  end

  def cancel
    if params[:reason].present?
      @sale.cancel!(params[:reason])
      redirect_to sale_path(@sale), notice: "Sale #{@sale.sale_no} cancelled."
    else
      redirect_to sale_path(@sale), alert: "Please give a reason for cancelling."
    end
  end

  private

  def set_sale
    @sale = Sale.shop.includes(:customer, :stock_unit, :agent).find(params[:id])
  end

  def filter_by(scope)
    scope = scope.where(sale_type: params[:type]) if params[:type].present?
    scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    if params[:from].present? || params[:to].present?
      from = params[:from].presence&.to_date || 100.years.ago.to_date
      to = params[:to].presence&.to_date || Date.current
      scope = scope.between(from, to)
    end
    scope
  end

  def load_form_collections
    @customers = Customer.shop.active.order(:name)
    @stock_units = StockUnit.shop.available.includes(:product, :variant)
    @payment_modes = PaymentMode.shop.cash_first
    @agents = Agent.shop.active.order(:name)
    @salesmen = User.shop.active.where(role: %w[shop_admin branch_manager cashier]).order(:full_name)
  end

  def sale_params
    params.require(:sale).permit(
      :sale_date, :customer_id, :sale_type, :product_id, :variant_id, :stock_unit_id, :reg_no,
      :total_amount, :discount, :down_payment, :months, :cost_amount, :payment_mode_id,
      :agent_id, :salesman_id, :late_fee_type, :notes,
      items_attributes: %i[id product_id variant_id stock_unit_id description qty unit_price discount serial_no _destroy]
    )
  end
end
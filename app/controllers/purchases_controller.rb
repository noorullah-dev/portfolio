class PurchasesController < ApplicationController

  guard index: "purchases.view", show: "purchases.view", new: "purchases.create", create: "purchases.create", edit: "purchases.edit", update: "purchases.edit", destroy: "purchases.delete", print: "purchases.view"
  before_action :set_purchase, only: %i[show edit update destroy]

  def index
    @purchases = Purchase.shop.search(params[:q]).recent.includes(:supplier, :payment_mode)
    @purchases = @purchases.where(supplier_id: params[:supplier_id]) if params[:supplier_id].present?
    @purchases = paginate(@purchases)
    @total_count = @purchases.total_count
  end

  def show
    @items = @purchase.items.includes(:product, :variant)
    @payments = @purchase.payments.recent.includes(:payment_mode, :created_by)
  end

  def new
    @purchase = Purchase.new(purchase_date: Date.current, supplier_id: params[:supplier_id])
    # one blank row so the form still saves a single-item purchase without JS
    @purchase.items.build(qty: 1, create_stock_unit: true)
    load_form_collections
  end

  def create
    @purchase = Purchase.new(purchase_params)
    @purchase.created_by = current_user

    if @purchase.save
      redirect_to purchase_path(@purchase), notice: "Purchase #{@purchase.purchase_no} recorded."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_collections
  end

  def update
    @purchase.assign_attributes(purchase_params.except(:items_attributes))

    if @purchase.save
      redirect_to purchase_path(@purchase), notice: "Purchase #{@purchase.purchase_no} updated."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @purchase.payments.any?
      redirect_to purchase_path(@purchase), alert: "Delete the payments before removing this purchase."
    else
      @purchase.destroy
      redirect_to purchases_path, notice: "Purchase deleted."
    end
  end

  private

  def set_purchase
    @purchase = Purchase.shop.includes(:supplier).find(params[:id])
  end

  def load_form_collections
    @suppliers = Supplier.shop.active.order(:name)
    @products = Product.shop.active.includes(:variants).order(:name)
    @payment_modes = PaymentMode.shop.cash_first
  end

  def purchase_params
    params.require(:purchase).permit(
      :purchase_date, :supplier_id, :invoice_no, :discount, :total_amount, :paid_amount,
      :payment_type, :payment_mode_id, :status, :notes,
      items_attributes: %i[id product_id variant_id description qty unit_price engine_no chassis_no
                           create_stock_unit _destroy]
    )
  end
end
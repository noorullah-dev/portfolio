class QuotationsController < ApplicationController

  guard index: "quotations.view", show: "quotations.view", new: "quotations.create", create: "quotations.create", edit: "quotations.edit", update: "quotations.edit", accept: "quotations.accept", destroy: "quotations.delete", print: "quotations.view"
  before_action :set_quotation, only: %i[accept destroy]

  def index
    @quotations = Quotation.shop.includes(:customer, :product, :variant)
    @quotations = @quotations.where(status: params[:status]) if params[:status].present?
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      @quotations = @quotations.where("quotation_no ILIKE :q OR customer_name ILIKE :q", q: term)
    end
    @quotations = paginate(@quotations.recent, per_page: 25)

    @summary = {
      open: Quotation.shop.open_quotes.count,
      accepted: Quotation.shop.where(status: %w[accepted converted]).count,
      value: Quotation.shop.open_quotes.sum(:sale_price)
    }
  end

  def new
    @quotation = Quotation.new(quotation_date: Date.current, valid_until: Date.current + 14.days,
                               customer_id: params[:customer_id], months: 12)
    load_collections
  end

  def create
    @quotation = Quotation.new(quotation_params)
    @quotation.created_by = current_user
    @quotation.customer_name ||= @quotation.customer&.name
    @quotation.customer_phone ||= @quotation.customer&.phone

    if @quotation.save
      @quotation.update!(status: "sent") if params[:send_now]
      redirect_to quotations_path, notice: "Quotation #{@quotation.quotation_no} created."
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  # Marks a quotation as converted and seeds a sale draft from it.
  def accept
    sale = Sale.create!(
      customer: @quotation.customer,
      sale_date: Date.current,
      sale_type: @quotation.months.to_i.positive? ? "credit" : "cash",
      product: @quotation.product,
      variant: @quotation.variant,
      stock_unit: stock_unit_for_quotation,
      total_amount: @quotation.sale_price,
      down_payment: @quotation.down_payment,
      months: @quotation.months,
      notes: "Converted from quotation #{@quotation.quotation_no}",
      created_by: current_user
    )

    @quotation.accept!(sale: sale)
    redirect_to sale_path(sale), notice: "Quotation #{@quotation.quotation_no} converted to sale #{sale.sale_no}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to quotations_path, alert: "Could not convert: #{e.record.errors.full_messages.to_sentence}"
  end

  def destroy
    @quotation.destroy
    redirect_to quotations_path, notice: "Quotation deleted."
  end

  private

  # A converted quotation should leave inventory in the same state a direct
  # sale would: claim a matching available vehicle, or record one on the spot.
  def stock_unit_for_quotation
    return @quotation.stock_unit if @quotation.respond_to?(:stock_unit) && @quotation.stock_unit
    return nil if @quotation.product.blank?

    scope = StockUnit.shop.available.where(product_id: @quotation.product_id)
    scope = scope.where(variant_id: @quotation.variant_id) if @quotation.variant_id
    scope.first || StockUnit.create!(
      product: @quotation.product,
      variant: @quotation.variant,
      vehicle_model: @quotation.product.display_name,
      cost_price: @quotation.product.cost_price,
      date_added: Date.current
    )
  end

  def set_quotation
    @quotation = Quotation.shop.includes(:customer, :product, :variant).find(params[:id])
  end

  def load_collections
    @customers = Customer.shop.active.order(:name)
    @products = Product.shop.active.includes(:variants).order(:name)
  end

  def quotation_params
    params.require(:quotation).permit(:quotation_date, :valid_until, :customer_id, :product_id, :variant_id,
                                       :stock_unit_id, :sale_price, :down_payment, :months, :notes, :status)
  end
end
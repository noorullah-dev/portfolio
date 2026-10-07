class StockUnitsController < ApplicationController

  guard index: "stock.view", show: "stock.view", edit: "stock.edit", update: "stock.edit", destroy: "stock.edit", reserve: "stock.reserve", release: "stock.reserve"
  before_action :set_stock_unit, only: %i[show edit update destroy]

  def index
    @stock_units = StockUnit.shop.includes(:product, :variant, :supplier, :sale)
    @stock_units = filter_by(@stock_units)
    @stock_units = @stock_units.order(date_added: :desc, id: :desc)
    @summary = {
      total: StockUnit.shop.count,
      available: StockUnit.shop.available.count,
      sold: StockUnit.shop.sold.count,
      value: StockUnit.shop.available.sum(:cost_price)
    }
  end

  def show; end

  def edit; end

  def update
    if @stock_unit.update(stock_unit_params)
      redirect_to stock_units_path, notice: "Stock unit #{@stock_unit.label} updated."
    else
      flash.now[:alert] = @stock_unit.errors.full_messages.to_sentence
      render :edit
    end
  end

  def destroy
    if @stock_unit.sold?
      redirect_to stock_units_path, alert: "A sold vehicle cannot be deleted."
    else
      @stock_unit.destroy
      redirect_to stock_units_path, notice: "Stock unit removed."
    end
  end

  private

  def set_stock_unit
    @stock_unit = StockUnit.shop.find(params[:id])
  end

  def filter_by(scope)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(product_id: params[:product_id]) if params[:product_id].present?
    if params[:q].present?
      term = "%#{sanitize_sql_like(params[:q].to_s.strip)}%"
      scope = scope.where(
        "stock_units.engine_no ILIKE :q OR stock_units.chassis_no ILIKE :q OR products.name ILIKE :q OR variants.name ILIKE :q",
        q: term
      ).left_joins(:product, :variant)
    end
    scope
  end

  def stock_unit_params
    params.require(:stock_unit).permit(:status, :cost_price, :sale_price, :date_added, :remarks)
  end
end
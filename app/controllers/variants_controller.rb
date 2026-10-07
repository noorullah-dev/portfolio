class VariantsController < ApplicationController

  guard index: "variants.view", new: "variants.create", create: "variants.create", edit: "variants.edit", update: "variants.edit", destroy: "variants.delete"
  before_action :set_variant, only: %i[show edit update destroy]

  def index
    @variants = Variant.shop.includes(:product)
    @variants = @variants.where(product_id: params[:product_id]) if params[:product_id].present?
    @variants = @variants.order(:value)
    @products = Product.shop.active.order(:name)
  end

  def show; end

  def new
    @variant = Variant.new(product_id: params[:product_id] || params.dig(:variant, :product_id))
    load_collections
  end

  def create
    @variant = Variant.new(variant_params)

    if @variant.save
      redirect_to variants_path, notice: "Variant #{@variant.display_name} created."
    else
      load_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_collections
  end

  def update
    if @variant.update(variant_params)
      redirect_to variants_path, notice: "Variant updated."
    else
      load_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @variant.stock_units.exists?
      redirect_to variants_path, alert: "This variant still has stock units and cannot be deleted."
    else
      @variant.destroy
      redirect_to variants_path, notice: "Variant deleted."
    end
  end

  private

  def set_variant
    @variant = Variant.shop.includes(:product).find(params[:id])
  end

  def load_collections
    @products = Product.shop.active.order(:name)
  end

  def variant_params
    params.require(:variant).permit(:product_id, :value, :purchase_price, :sale_price, :status)
  end
end
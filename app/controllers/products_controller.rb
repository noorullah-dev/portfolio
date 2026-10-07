class ProductsController < CrudController
  self.resource_class = Product
  self.permission_module = :products
  self.page_title = "Products"
  self.page_icon = "bi-box-seam"
  self.page_subtitle = "Manage product catalogue"
  self.permitted_attributes = %i[name brand_id category_id status]
  self.search_columns = %i[name]
  self.search_placeholder = "Search products"
  self.default_order = { name: :asc }
  self.new_path = -> { new_product_path }
  self.show_path = ->(record) { product_path(record) }
  self.edit_path = ->(record) { edit_product_path(record) }
  self.destroy_path = ->(record) { product_path(record) }

  self.filter_options = [
    { param: :brand_id, options: -> { [["All brands", ""]] + Brand.shop.active.order(:name).pluck(:name, :id) } },
    { param: :category_id, options: -> { [["All categories", ""]] + Category.shop.active.order(:name).pluck(:name, :id) } }
  ]

  self.columns = [
    { label: "#", class: "text-end", value: ->(record) { tag.code(record.id) } },
    { label: "Brand", value: ->(record) { record.brand&.name || "—" } },
    { label: "Category", value: ->(record) { record.category&.name || "—" } },
    { label: "Model Name", value: ->(record) { record.display_name } },
    { label: "Variants", class: "text-end", value: ->(record) { record.variants.count } },
    { label: "In stock", class: "text-end", value: ->(record) { record.stock_units.available.count } },
    { label: "Status", value: ->(record) { status_badge(record.status) } }
  ]

  self.fields = [
    { name: "name", label: "Product name", type: :string, col: 4 },
    { name: "brand_id", label: "Brand", type: :select, col: 4,
      collection: -> { Brand.shop.active.order(:name).pluck(:name, :id) } },
    { name: "category_id", label: "Category", type: :select, col: 4,
      collection: -> { Category.shop.active.order(:name).pluck(:name, :id) } },
    { name: "status", label: "Status", type: :select, col: 3,
      collection: -> { [%w[Active active], %w[Inactive inactive]] } }
  ]

  private

  def base_scope
    Product.shop.includes(:brand, :category, :variants)
  end

  def apply_filters(scope)
    scope = scope.where(brand_id: params[:brand_id]) if params[:brand_id].present?
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    scope
  end
end
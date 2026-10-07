class BrandsController < CrudController
  self.resource_class = Brand
  self.permission_module = :brands
  self.page_title = "Brands"
  self.page_icon = "bi-tag"
  self.page_subtitle = "Vehicle and electronics brands you sell"
  self.permitted_attributes = %i[name status]
  self.search_columns = %i[name]
  self.search_placeholder = "Search brands"
  self.new_path = -> { new_brand_path }
  self.show_path = ->(record) { brand_path(record) }
  self.edit_path = ->(record) { edit_brand_path(record) }
  self.destroy_path = ->(record) { brand_path(record) }

  self.columns = [
    { label: "#", class: "text-end", value: ->(record) { tag.code(record.id) } },
    { label: "Brand Name", value: ->(record) { record.name } },
    { label: "Products", class: "text-end", value: ->(record) { record.products.count } },
    { label: "In stock", class: "text-end", value: ->(record) { record.stock_units.available.count } },
    { label: "Status", value: ->(record) { status_badge(record.status) } }
  ]

  self.fields = [
    { name: "name", label: "Brand name", type: :string, col: 6 },
    { name: "status", label: "Status", type: :select, col: 3,
      collection: -> { [%w[Active active], %w[Inactive inactive]] } }
  ]

  private

  def base_scope
    Brand.shop.includes(:products)
  end
end
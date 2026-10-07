class CategoriesController < CrudController
  self.resource_class = Category
  self.permission_module = :categories
  self.page_title = "Categories"
  self.page_icon = "bi-grid-3x3-gap"
  self.page_subtitle = "Vehicle models and accessory groups"
  self.permitted_attributes = %i[name category_type serial_no warranty_months status]
  self.search_columns = %i[name serial_no]
  self.search_placeholder = "Search categories"
  self.default_order = { name: :asc }
  self.new_path = -> { new_category_path }
  self.show_path = ->(record) { category_path(record) }
  self.edit_path = ->(record) { edit_category_path(record) }
  self.destroy_path = ->(record) { category_path(record) }

  self.filter_options = [
    { param: :category_type,
      options: [["All types", ""], %w[Vehicle vehicle], %w[Electronics electronics], %w[General general]] }
  ]

  self.columns = [
    { label: "#", class: "text-end", value: ->(record) { tag.code(record.id) } },
    { label: "Category Name", value: ->(record) { record.name } },
    { label: "Type", value: ->(record) { record.category_type.humanize } },
    { label: "Serial No", value: ->(record) { record.serial_no.presence || "—" } },
    { label: "Warranty", class: "text-end", value: ->(record) { "#{record.warranty_months} mo" } },
    { label: "Status", value: ->(record) { status_badge(record.status) } }
  ]

  self.fields = [
    { name: "name", label: "Category name", type: :string, col: 4 },
    { name: "category_type", label: "Type", type: :select, col: 4,
      collection: -> { [%w[Vehicle vehicle], %w[Electronics electronics], %w[General general]] } },
    { name: "serial_no", label: "Serial / code", type: :string, col: 4 },
    { name: "warranty_months", label: "Warranty (months)", type: :number, col: 3, min: 0 },
    { name: "status", label: "Status", type: :select, col: 3,
      collection: -> { [%w[Active active], %w[Inactive inactive]] } }
  ]

  private

  def base_scope
    Category.shop.includes(:products)
  end

  def apply_filters(scope)
    scope = scope.where(category_type: params[:category_type]) if params[:category_type].present?
    scope
  end
end
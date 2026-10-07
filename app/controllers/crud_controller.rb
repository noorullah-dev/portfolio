# Base for the many plain catalogue/list screens. Each controller declares its
# model, columns, permitted attributes and search behaviour; the shared views in
# app/views/shared render index, form and show.
class CrudController < ApplicationController
  before_action :authorize_crud!
  before_action :set_record, only: %i[show edit update destroy]

  helper_method :form_action_path, :form_http_method, :index_path, :actions_label

  class_attribute :resource_class, instance_writer: false
  # Permission module used by authorize_crud! (e.g. :products -> products.view)
  class_attribute :permission_module, instance_writer: false
  class_attribute :page_title, instance_writer: false
  class_attribute :page_subtitle, instance_writer: false
  class_attribute :page_icon, default: "bi-list-ul", instance_writer: false
  class_attribute :per_page, default: 25, instance_writer: false
  class_attribute :permitted_attributes, default: [], instance_writer: false
  class_attribute :search_columns, default: [], instance_writer: false
  class_attribute :default_order, default: { id: :desc }, instance_writer: false
  class_attribute :form_partial, instance_writer: false
  class_attribute :after_save_path, instance_writer: false
  class_attribute :columns, default: [], instance_writer: false
  class_attribute :fields, default: [], instance_writer: false
  class_attribute :new_path, default: nil, instance_writer: false
  class_attribute :new_button_label, default: nil, instance_writer: false
  class_attribute :count_label, default: nil, instance_writer: false
  class_attribute :search_placeholder, default: "Search", instance_writer: false
  class_attribute :search_param, default: :q, instance_writer: false
  class_attribute :filter_options, default: nil, instance_writer: false
  class_attribute :show_path, default: nil, instance_writer: false
  class_attribute :edit_path, default: nil, instance_writer: false
  class_attribute :destroy_path, default: nil, instance_writer: false
  # Header text for the trailing actions column (the captured design uses both
  # "Actions" and "Action" depending on the screen).
  class_attribute :actions_label, default: "Actions", instance_writer: false

  def self.permissions_for_action(action)
    operation = { "index" => "view", "show" => "view", "new" => "create",
                  "create" => "create", "edit" => "edit", "update" => "edit",
                  "destroy" => "delete" }[action.to_s]
    return super unless permission_module && operation

    "#{permission_module}.#{operation}"
  end

  def index
    @records = paginate(filtered_scope, per_page: per_page)
    @total_count = @records.total_count
    render "shared/index"
  end

  def show
    render "shared/show"
  end

  def new
    @record = resource_class.new(new_record_defaults)
    render_form
  end

  def create
    @record = resource_class.new(record_params)
    if @record.save
      audit_change("create")
      redirect_to redirect_after_save, notice: success_notice("created")
    else
      render_form
    end
  end

  def edit
    render_form
  end

  def update
    if @record.update(record_params)
      audit_change("update")
      redirect_to redirect_after_save, notice: success_notice("updated")
    else
      render_form
    end
  end

  def destroy
    if @record.destroy
      audit_change("delete", summary: "#{@record.class.name} #{record_label_for_audit} deleted")
      redirect_to index_path, notice: success_notice("deleted")
    else
      redirect_to index_path, alert: destroy_error
    end
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
    redirect_to index_path, alert: destroy_error
  end

  private

  # Every write through the generic CRUD screens lands in the activity log with
  # the fields that actually changed.
  def audit_change(action, summary: nil)
    Current.audit!(:"#{permission_module}.#{action}",
                   record: (defined?(@record) && @record),
                   summary: summary || "#{resource_class.name} #{record_label_for_audit} #{action}d",
                   changes: audit_changes)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def record_label_for_audit
    @record.respond_to?(:to_s) ? @record.to_s : @record.id.to_s
  end

  def audit_changes
    return {} unless @record.respond_to?(:saved_changes)

    @record.saved_changes.to_h do |attribute, (before, after)|
      [attribute, { "from" => before, "to" => after }]
    end
  rescue StandardError
    {}
  end

  def model
    self.class.resource_class
  end

  # index/show -> <module>.view, new/create -> <module>.create,
  # edit/update -> <module>.edit, destroy -> <module>.delete
  def authorize_crud!
    required = self.class.permissions_for_action(action_name)
    authorize_any!(*Array(required)) if required.present?
  end

  def form_partial?
    self.class.form_partial.present?
  end

  def form_partial
    self.class.form_partial
  end

  def render_form
    render(form_partial? ? form_partial : "shared/form")
  end

  def render_form_template
    form_partial? ? form_partial : "shared/form"
  end

  def filtered_scope
    scope = base_scope
    scope = apply_search(scope) if params[:q].present? && self.class.search_columns.any?
    scope = apply_filters(scope)
    scope.order(**default_order_value)
  end

  # Tenant filter first, so a record from another shop can never be listed or
  # reached even if a filter/search clause matches it.
  def base_scope
    model.shop
  end

  def apply_search(scope)
    term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
    clauses = self.class.search_columns.map { |column| "#{model.table_name}.#{column} ILIKE :term" }
    scope.where(clauses.join(" OR "), term: term)
  end

  def apply_filters(scope)
    scope
  end

  def default_order_value
    value = self.class.default_order
    value.is_a?(Proc) ? instance_exec(&value) : value
  end

  def new_record_defaults
    {}
  end

  def set_record
    @record = model.shop.find(params[:id])
  end

  def record_params
    params.require(model.model_name.param_key).permit(*self.class.permitted_attributes)
  end

  def index_path
    polymorphic_path(model)
  end

  # The shared form posts to the collection for a new record and to the member
  # path for a persisted one (url_for(action: params[:action]) would post to
  # /customers/new and patch /customers/1/edit, which do not exist).
  def form_action_path
    @record.persisted? ? polymorphic_path(@record) : polymorphic_path(model)
  end

  def form_http_method
    @record.persisted? ? :patch : :post
  end

  def redirect_after_save
    path = self.class.after_save_path
    (path && instance_exec(self, &path)) || index_path
  end

  def destroy_error
    @record.errors.full_messages.to_sentence.presence ||
      "#{page_title} is still used by other records, so it cannot be deleted."
  end

  def success_notice(action)
    "#{page_title} #{action}."
  end
end

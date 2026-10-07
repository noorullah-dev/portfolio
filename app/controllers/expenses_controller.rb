class ExpensesController < CrudController
  self.resource_class = Expense
  self.permission_module = :expenses
  self.actions_label = "Action"
  self.page_title = "Expenses"
  self.page_icon = "bi-cash"
  self.page_subtitle = "Running expenses by category"
  self.permitted_attributes = %i[expense_date category_id description amount payment_mode_id account_id reference]
  self.search_columns = %i[description reference]
  self.search_placeholder = "Search expenses"
  self.default_order = { expense_date: :desc, id: :desc }
  self.new_path = -> { new_expense_path }
  self.show_path = ->(record) { expense_path(record) }
  self.edit_path = ->(record) { edit_expense_path(record) }
  self.destroy_path = ->(record) { expense_path(record) }
  self.filter_options = [
    { param: :category_id, options: -> { [["All categories", ""]] + ExpenseCategory.shop.active.pluck(:name, :id) } }
  ]

  self.columns = [
    { label: "Date", value: ->(record) { qm_date(record.expense_date) } },
    { label: "Category", value: ->(record) { record.category&.name || "—" } },
    { label: "Description", value: ->(record) { record.description.presence || "—" } },
    { label: "Amount", class: "text-end", value: ->(record) { money(record.amount) } },
    { label: "Mode", value: ->(record) { record.payment_mode&.name || "—" } },
    { label: "Added By", value: ->(record) { record.added_by&.full_name.presence || "—" } }
  ]

  self.fields = [
    { name: "expense_date", label: "Date", type: :date, col: 3 },
    { name: "category_id", label: "Category", type: :select, col: 3,
      collection: -> { ExpenseCategory.shop.active.pluck(:name, :id) } },
    { name: "amount", label: "Amount", type: :decimal, col: 3 },
    { name: "payment_mode_id", label: "Payment mode", type: :select, col: 3,
      collection: -> { PaymentMode.shop.cash_first.pluck(:name, :id) } },
    { name: "account_id", label: "Expense account", type: :select, col: 4,
      collection: -> { ChartOfAccount.shop.of_type("expense").pluck { |a| ["#{a.code} #{a.name}", a.id] } } },
    { name: "reference", label: "Reference", type: :string, col: 4 },
    { name: "description", label: "Description", type: :textarea, col: 8 }
  ]

  def create
    @record = Expense.new(record_params)
    @record.added_by = current_user
    @record.account ||= default_expense_account
    save_or_render
  end

  def update
    @record.assign_attributes(record_params)
    save_or_render
  end

  private

  def base_scope
    Expense.shop.includes(:category, :payment_mode, :account)
  end

  def new_record_defaults
    { expense_date: Date.current }
  end

  def apply_filters(scope)
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    scope = scope.between(*month_range) if params[:month].present?
    scope
  end

  def month_range
    date = params[:month].to_date
    date.beginning_of_month..date.end_of_month
  end

  def save_or_render
    if @record.save
      redirect_to expenses_path, notice: "Expense saved."
    else
      render_form
    end
  end

  def default_expense_account
    ChartOfAccount.shop.find_by(code: Business::DEFAULT_EXPENSE_CODE) || ChartOfAccount.of_type("expense").first
  end
end
class ChartOfAccountsController < CrudController
  self.resource_class = ChartOfAccount
  self.permission_module = :accounts
  self.page_title = "Chart of Accounts"
  self.page_icon = "bi-diagram-3"
  self.page_subtitle = "Ledger heads used for double entry"
  self.permitted_attributes = %i[code name account_type parent_id is_cash_account status]
  self.search_columns = %i[code name]
  self.search_placeholder = "Search code or account name"
  self.default_order = { code: :asc }
  self.new_path = -> { new_chart_of_account_path }
  self.show_path = ->(record) { chart_of_account_path(record) }
  self.edit_path = ->(record) { edit_chart_of_account_path(record) }
  self.destroy_path = ->(record) { chart_of_account_path(record) }
  self.filter_options = [
    { param: :account_type, options: -> { [["All types", ""]] + ChartOfAccount::TYPES.map { |t| [t.humanize, t] } } },
    { param: :inactive, options: [["Active only", ""], ["Show inactive", "1"]] }
  ]

  self.columns = [
    { label: "Code", value: ->(record) { tag.code(record.code) } },
    { label: "Name", value: ->(record) { record.name } },
    { label: "Type", value: ->(record) { status_badge(record.account_type) } },
    { label: "Parent Account", value: ->(record) { record.parent&.name || "—" } },
    { label: "Debits", class: "text-end", value: ->(record) { money(record.debit_balance) } },
    { label: "Credits", class: "text-end", value: ->(record) { money(record.credit_balance) } },
    { label: "Balance", class: "text-end", value: ->(record) { money(record.balance) } },
    { label: "Status", value: ->(record) { status_badge(record.status) } }
  ]

  self.fields = [
    { name: "code", label: "Code", type: :string, col: 2 },
    { name: "name", label: "Account name", type: :string, col: 4 },
    { name: "account_type", label: "Type", type: :select, col: 3,
      collection: -> { ChartOfAccount::TYPES.map { |t| [t.humanize, t] } } },
    { name: "parent_id", label: "Parent account", type: :select, col: 3,
      collection: -> { ChartOfAccount.shop.where.not(id: @record&.id).order(:code).map { |a| ["#{a.code} #{a.name}", a.id] } } },
    { name: "is_cash_account", label: "Treat as a cash account", type: :check_box, col: 3,
      hint: "Used by the cash book when choosing an account." },
    { name: "status", label: "Status", type: :select, col: 3,
      collection: -> { [%w[Active active], %w[Inactive inactive]] } }
  ]

  private

  def apply_filters(scope)
    scope = scope.where(account_type: params[:account_type]) if params[:account_type].present?
    scope = scope.where(status: "inactive") if params[:inactive].present?
    scope
  end
end
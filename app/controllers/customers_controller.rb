class CustomersController < CrudController
  self.resource_class = Customer
  self.permission_module = :customers
  self.page_title = "Customers"
  self.page_icon = "bi-people"
  self.page_subtitle = "Customer accounts, balances and arrears"
  self.permitted_attributes = %i[name account_no father_name cnic phone alt_phone address city
                                  customer_type business_name email credit_limit opening_balance
                                  agent_id salesman_id location_id status remarks]
  self.search_columns = %i[name account_no phone cnic]
  self.search_placeholder = "Search name, account, phone or CNIC"
  self.default_order = { name: :asc }
  self.new_path = -> { new_customer_path }
  self.show_path = ->(record) { customer_path(record) }
  self.edit_path = ->(record) { edit_customer_path(record) }
  self.destroy_path = ->(record) { customer_path(record) }

  self.filter_options = [
    { param: :status, options: [%w[All statuses], %w[Active active], %w[Inactive inactive]] },
    { param: :defaulter, options: [["All customers", ""], ["Defaulters only", "1"]] }
  ]

  self.columns = [
    { label: "Account No", value: ->(record) { tag.code(record.account_no) } },
    { label: "Name", value: ->(record) { record.name } },
    { label: "CNIC", value: ->(record) { record.cnic.presence || "—" } },
    { label: "Phone", value: ->(record) { record.phone.presence || "—" } },
    { label: "Type", value: ->(record) { record.customer_type.humanize } },
    { label: "Status", value: ->(record) { status_badge(record.status) } },
    { label: "Defaulter", value: ->(record) { record.defaulter? ? status_badge("overdue") : status_badge("active") } }
  ]

  self.fields = [
    { name: "name", label: "Customer name", type: :string, col: 4 },
    { name: "father_name", label: "Father / husband name", type: :string, col: 4 },
    { name: "customer_type", label: "Type", type: :select, col: 4,
      collection: -> { [%w[Individual individual], %w[Company company]] } },
    { name: "cnic", label: "CNIC", type: :string, col: 4 },
    { name: "phone", label: "Phone", type: :tel, col: 4 },
    { name: "alt_phone", label: "Alternate phone", type: :tel, col: 4 },
    { name: "city", label: "City", type: :string, col: 4 },
    { name: "email", label: "Email", type: :email, col: 4 },
    { name: "credit_limit", label: "Credit limit", type: :decimal, col: 4 },
    { name: "opening_balance", label: "Opening balance", type: :decimal, col: 4,
      hint: "Positive means the customer already owes this much." },
    { name: "agent_id", label: "Agent", type: :select, col: 4,
      collection: -> { Agent.shop.active.pluck(:name, :id) } },
    { name: "location_id", label: "Location", type: :select, col: 4,
      collection: -> { assigned_locations.pluck(:name, :id) } },
    { name: "salesman_id", label: "Salesman", type: :select, col: 4,
      collection: -> { User.shop.active.where(role: %w[cashier branch_manager]).pluck(:full_name, :id) } },
    { name: "status", label: "Status", type: :select, col: 4,
      collection: -> { [%w[Active active], %w[Inactive inactive]] } },
    { name: "address", label: "Address", type: :textarea, col: 12 },
    { name: "remarks", label: "Remarks", type: :textarea, col: 12 }
  ]

  def show
    @customer = @record
    unless location_allowed?(@record.location_id)
      redirect_to customers_path, alert: "That customer is outside your assigned locations."
      return
    end

    @sales = @record.sales.recent.includes(:payment_mode)
    @plans = InstallmentPlan.shop.where(sale_id: @record.active_sales.select(:id))
                            .where.not(status: "paid")
                            .order(:due_date)
    @payments = @record.installment_payments.recent.includes(:payment_mode).limit(20)
    @cheques = @record.post_dated_cheques.recent
    @reminders = @record.installment_reminders.order(sent_at: :desc).limit(20)
    @documents = @record.vehicle_documents

    render "customers/show"
  end

  private

  def base_scope
    scoped_customers.includes(:agent)
  end

  # Shop-wide customers, narrowed to the recovery officer's assigned locations.
  def scoped_customers
    scope = Customer.shop
    scope = scope.where(location_id: allowed_location_ids) if location_restricted?
    scope
  end

  def apply_filters(scope)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where("EXISTS (#{overdue_sql})") if params[:defaulter].present?
    scope
  end

  def overdue_sql
    <<~SQL
      SELECT 1 FROM installment_plans ip
      WHERE ip.sale_id IN (SELECT id FROM sales WHERE customer_id = customers.id)
        AND ip.status <> 'paid' AND ip.due_date < CURRENT_DATE
    SQL
  end
end
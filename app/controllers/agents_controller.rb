class AgentsController < CrudController
  self.resource_class = Agent
  self.permission_module = :agents
  self.page_title = "Agents"
  self.page_icon = "bi-person-badge"
  self.page_subtitle = "Commission earning agents"
  self.permitted_attributes = %i[name cnic phone city address commission_type commission_amount status]
  self.search_columns = %i[name phone city]
  self.search_placeholder = "Search agents"
  self.new_path = -> { new_agent_path }
  self.show_path = ->(record) { agent_path(record) }
  self.edit_path = ->(record) { edit_agent_path(record) }
  self.destroy_path = ->(record) { agent_path(record) }
  self.after_save_path = ->(_controller) { agent_commissions_path }

  self.columns = [
    { label: "Name", value: ->(record) { record.name } },
    { label: "CNIC", value: ->(record) { record.cnic.presence || "—" } },
    { label: "Phone", value: ->(record) { record.phone.presence || "—" } },
    { label: "Commission Type", value: ->(record) { record.commission_type.humanize } },
    { label: "Commission Amount", class: "text-end", value: ->(record) { commission_rate(record) } },
    { label: "Earned", class: "text-end", value: ->(record) { money(record.total_earned) } },
    { label: "Paid", class: "text-end", value: ->(record) { money(record.total_paid) } },
    { label: "Status", value: ->(record) { status_badge(record.status) } }
  ]

  self.fields = [
    { name: "name", label: "Agent name", type: :string, col: 4 },
    { name: "cnic", label: "CNIC", type: :string, col: 4 },
    { name: "phone", label: "Phone", type: :tel, col: 4 },
    { name: "city", label: "City", type: :string, col: 4 },
    { name: "commission_type", label: "Commission type", type: :select, col: 4,
      collection: -> { [%w[Percent percent], %w[Fixed fixed]] } },
    { name: "commission_amount", label: "Rate / amount", type: :decimal, col: 4,
      hint: "Percent: 2 means 2%. Fixed: flat amount per sale." },
    { name: "status", label: "Status", type: :select, col: 4,
      collection: -> { [%w[Active active], %w[Inactive inactive]] } },
    { name: "address", label: "Address", type: :textarea, col: 12 }
  ]

end
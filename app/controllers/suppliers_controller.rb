class SuppliersController < CrudController
  guard ledger: "suppliers.ledger"
  self.resource_class = Supplier
  self.permission_module = :suppliers
  self.page_title = "Suppliers"
  self.page_icon = "bi-truck"
  self.page_subtitle = "Where your stock comes from"
  self.permitted_attributes = %i[name city phone address cnic opening_balance status]
  self.search_columns = %i[name city phone]
  self.search_placeholder = "Search suppliers"
  self.new_path = -> { new_supplier_path }
  self.show_path = ->(record) { supplier_path(record) }
  self.edit_path = ->(record) { edit_supplier_path(record) }
  self.destroy_path = ->(record) { supplier_path(record) }

  # Captured design exposes a per-supplier ledger (Date, Type, Reference,
  # Debit (Paid), Credit (Owed), Balance).
  def ledger
    @supplier = Supplier.shop.find(params[:id])

    entries = []
    @supplier.purchases.where.not(status: "cancelled").includes(:payments).each do |purchase|
      entries << {
        date: purchase.purchase_date,
        type: "Purchase",
        reference: purchase.purchase_no,
        particulars: purchase.items.map(&:description).compact.join(", ").presence || "Purchase",
        debit: 0,
        credit: purchase.total_amount.to_d
      }
      purchase.payments.each do |payment|
        entries << {
          date: payment.payment_date,
          type: "Payment",
          reference: payment.reference.presence || payment.payment_mode&.name,
          particulars: "Paid to supplier",
          debit: payment.amount.to_d,
          credit: 0
        }
      end
    end

    running = 0
    @entries = entries.sort_by { |e| [e[:date], e[:type]] }.map do |entry|
      running += entry[:credit] - entry[:debit]
      entry.merge(balance: running)
    end.reverse

    @totals = {
      debit: @entries.sum { |e| e[:debit] },
      credit: @entries.sum { |e| e[:credit] }
    }
    @closing = @totals[:credit] - @totals[:debit] + @supplier.opening_balance.to_d

    render "suppliers/ledger"
  end

  self.columns = [
    { label: "Supplier", value: ->(record) { record.name } },
    { label: "City", value: ->(record) { record.city.presence || "—" } },
    { label: "Phone", value: ->(record) { record.phone.presence || "—" } },
    { label: "Purchases", class: "text-end", value: ->(record) { money(record.total_purchases) } },
    { label: "Paid", class: "text-end", value: ->(record) { money(record.total_paid) } },
    { label: "Balance", class: "text-end", value: ->(record) { money(record.balance) } },
    { label: "Ledger", value: ->(record) { permitted_link_to "Ledger", ledger_supplier_path(record), class: "btn btn-sm btn-outline-secondary" } },
    { label: "Status", value: ->(record) { status_badge(record.status) } }
  ]

  self.fields = [
    { name: "name", label: "Supplier name", type: :string, col: 4 },
    { name: "city", label: "City", type: :string, col: 4 },
    { name: "phone", label: "Phone", type: :tel, col: 4 },
    { name: "cnic", label: "CNIC / NTN", type: :string, col: 4 },
    { name: "opening_balance", label: "Opening balance", type: :decimal, col: 4 },
    { name: "status", label: "Status", type: :select, col: 4,
      collection: -> { [%w[Active active], %w[Inactive inactive]] } },
    { name: "address", label: "Address", type: :textarea, col: 12 }
  ]
end

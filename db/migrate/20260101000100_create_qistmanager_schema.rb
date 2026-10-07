require_relative "schema_definitions"

class CreateQistmanagerSchema < ActiveRecord::Migration[8.1]
  def quote(value)
    connection.quote(value)
  end

  def up
    TABLES.each do |definition|
      create_table definition[:table] do |t|
        definition[:columns].each do |(name, type, options)|
          options ||= {}
          if type == :decimal && !options.key?(:precision)
            options = options.merge(precision: 15, scale: 2)
          end
          t.column name, type, **options
        end

        t.timestamps null: false
      end

      (definition[:indexes] || []).each do |(table, columns, options)|
        add_index table, columns, **(options || {})
      end

      if definition[:comment]
        execute(
          "COMMENT ON TABLE #{definition[:table]} IS #{quote(definition[:comment])}"
        )
      end
    end

    add_foreign_key :products, :brands
    add_foreign_key :products, :categories
    add_foreign_key :variants, :products
    add_foreign_key :sales, :customers
    add_foreign_key :sales, :users, column: :created_by_id
    add_foreign_key :sales, :payment_modes, column: :payment_mode_id
    add_foreign_key :sale_items, :sales
    add_foreign_key :sale_items, :stock_units
    add_foreign_key :installment_plans, :sales
    add_foreign_key :installment_payments, :sales
    add_foreign_key :installment_payments, :installment_plans
    add_foreign_key :purchases, :suppliers
    add_foreign_key :purchase_items, :purchases
    add_foreign_key :stock_units, :variants
    add_foreign_key :stock_units, :sales
    add_foreign_key :vouchers, :users, column: :created_by_id
    add_foreign_key :journal_voucher_lines, :journal_vouchers
    add_foreign_key :journal_voucher_lines, :chart_of_accounts, column: :account_id
    add_foreign_key :ledger_entries, :chart_of_accounts, column: :account_id
    add_foreign_key :ledger_entries, :users, column: :created_by_id
    add_foreign_key :expenses, :expense_categories, column: :category_id
    add_foreign_key :customers, :agents
    add_foreign_key :account_transfers, :customers, column: :from_customer_id
    add_foreign_key :account_transfers, :customers, column: :to_customer_id
    add_foreign_key :post_dated_cheques, :customers
    add_foreign_key :agent_commissions, :agents
    add_foreign_key :agent_commissions, :sales
    add_foreign_key :agent_commission_payments, :agent_commissions
    add_foreign_key :advance_bookings, :customers
    add_foreign_key :advance_booking_payments, :advance_bookings
    add_foreign_key :advance_booking_plans, :advance_bookings
    add_foreign_key :registration_trackings, :sales
    add_foreign_key :registration_trackings, :customers
    add_foreign_key :vehicle_documents, :sales
    add_foreign_key :credit_recoveries, :sales
    add_foreign_key :quotations, :customers
    add_foreign_key :account_closures, :customers
    add_foreign_key :account_closures, :sales
    add_foreign_key :installment_reminders, :installment_plans
  end

  def down
    TABLES.reverse_each do |definition|
      drop_table definition[:table]
    end
  end
end

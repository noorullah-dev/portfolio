class MultiTenancy < ActiveRecord::Migration[8.1]
  def change
    # ---------------------------------------------------------------- branches
    create_table :branches do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code
      t.string :branch_type, null: false, default: "main"
      t.text :address
      t.string :city
      t.string :phone
      t.string :status, null: false, default: "active"
      t.boolean :is_default, null: false, default: false
      t.timestamps
    end
    add_index :branches, %i[business_id name], unique: true

    # --------------------------------------------------------------- locations
    create_table :locations do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.string :city
      t.string :zone
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :locations, %i[business_id name], unique: true

    # Recovery officers / staff are assigned to the locations they cover.
    create_table :user_locations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_locations, %i[user_id location_id], unique: true

    # ------------------------------------------------------------- audit trail
    create_table :audit_logs do |t|
      t.bigint :business_id
      t.bigint :branch_id
      t.bigint :user_id
      t.string :role
      t.string :action, null: false
      t.string :record_type
      t.bigint :record_id
      t.bigint :subject_user_id
      t.text :summary
      t.jsonb :changes, null: false, default: {}
      t.string :request_method
      t.string :request_path
      t.string :ip_address
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, %i[business_id created_at]
    add_index :audit_logs, %i[record_type record_id]
    add_index :audit_logs, %i[user_id created_at]

    # ------------------------------------------------- shops / users extension
    add_column :businesses, :status, :string, null: false, default: "active"
    add_column :businesses, :provisioned_by_id, :bigint
    add_column :businesses, :plan, :string, null: false, default: "standard"
    add_column :businesses, :slug, :string
    add_index :businesses, :slug, unique: true
    add_index :businesses, :status

    add_column :users, :branch_id, :bigint
    add_column :users, :customer_id, :bigint
    add_column :users, :permissions_scope, :string, null: false, default: "branch"
    add_index :users, :branch_id
    add_index :users, :customer_id

    add_column :customers, :location_id, :bigint
    add_column :customers, :branch_id, :bigint
    add_index :customers, :location_id
    add_index :customers, :branch_id

    # ------------------------------------- tenant columns on business records
    tenant_tables = %w[
      account_closures account_transfers advance_booking_payments advance_booking_plans
      advance_bookings agent_commission_payments agent_commissions agents brands
      cash_book_entries categories chart_of_accounts credit_recoveries customers
      expense_categories expenses installment_payments installment_plans
      installment_reminders journal_voucher_lines journal_vouchers ledger_entries
      payment_modes post_dated_cheques products purchase_items purchase_payments
      purchases quotation_plans quotations registration_trackings sale_items sales
      stock_units suppliers variants vehicle_documents vouchers locations
    ]

    tenant_tables.each do |table|
      next unless table_exists?(table)

      add_column table, :business_id, :bigint unless column_exists?(table, :business_id)
      add_column table, :branch_id, :bigint unless column_exists?(table, :branch_id)
      add_index table, :business_id unless index_exists?(table, :business_id)
      add_index table, :branch_id unless index_exists?(table, :branch_id)
      add_index table, %i[business_id branch_id] unless index_exists?(table, %i[business_id branch_id])
    end

    end
end
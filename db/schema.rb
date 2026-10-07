# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_05_090800) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_closures", force: :cascade do |t|
    t.date "closure_date", null: false
    t.bigint "customer_id", null: false
    t.bigint "sale_id"
    t.decimal "remaining_balance", precision: 15, scale: 2, default: "0.0"
    t.decimal "settled_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "waived_amount", precision: 15, scale: 2, default: "0.0"
    t.string "reason"
    t.string "status", default: "completed"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_account_closures_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_account_closures_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_account_closures_on_business_id"
    t.index ["customer_id"], name: "index_account_closures_on_customer_id"
  end

  create_table "account_transfers", force: :cascade do |t|
    t.date "transfer_date", null: false
    t.bigint "customer_id", null: false
    t.bigint "from_customer_id", null: false
    t.bigint "to_customer_id", null: false
    t.bigint "sale_id"
    t.bigint "stock_unit_id"
    t.decimal "remaining_balance", precision: 15, scale: 2, default: "0.0"
    t.decimal "fee", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "pending"
    t.text "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_account_transfers_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_account_transfers_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_account_transfers_on_business_id"
    t.index ["from_customer_id"], name: "index_account_transfers_on_from_customer_id"
  end

  create_table "advance_booking_payments", force: :cascade do |t|
    t.bigint "advance_booking_id", null: false
    t.date "payment_date", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "payment_mode_id"
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["advance_booking_id"], name: "index_advance_booking_payments_on_advance_booking_id"
    t.index ["branch_id"], name: "index_advance_booking_payments_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_advance_booking_payments_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_advance_booking_payments_on_business_id"
  end

  create_table "advance_booking_plans", force: :cascade do |t|
    t.bigint "advance_booking_id", null: false
    t.integer "installment_no", null: false
    t.date "due_date", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "paid_amount", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["advance_booking_id"], name: "index_advance_booking_plans_on_advance_booking_id"
    t.index ["branch_id"], name: "index_advance_booking_plans_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_advance_booking_plans_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_advance_booking_plans_on_business_id"
  end

  create_table "advance_bookings", force: :cascade do |t|
    t.string "booking_no", null: false
    t.date "booking_date", null: false
    t.bigint "customer_id"
    t.string "customer_name"
    t.string "customer_phone"
    t.bigint "product_id"
    t.bigint "variant_id"
    t.bigint "stock_unit_id"
    t.string "sale_type", default: "credit"
    t.decimal "total_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "advance_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "balance_amount", precision: 15, scale: 2, default: "0.0"
    t.integer "months", default: 0
    t.decimal "monthly_amount", precision: 15, scale: 2, default: "0.0"
    t.date "expected_delivery"
    t.string "late_fee_type", default: "none"
    t.bigint "agent_id"
    t.string "status", default: "confirmed", null: false
    t.text "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["booking_no"], name: "index_advance_bookings_on_booking_no", unique: true
    t.index ["branch_id"], name: "index_advance_bookings_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_advance_bookings_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_advance_bookings_on_business_id"
    t.index ["status"], name: "index_advance_bookings_on_status"
  end

  create_table "agent_commission_payments", force: :cascade do |t|
    t.bigint "agent_commission_id", null: false
    t.date "payment_date", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "payment_mode_id"
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["agent_commission_id"], name: "index_agent_commission_payments_on_agent_commission_id"
    t.index ["branch_id"], name: "index_agent_commission_payments_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_agent_commission_payments_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_agent_commission_payments_on_business_id"
  end

  create_table "agent_commissions", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "sale_id", null: false
    t.bigint "customer_id"
    t.date "sale_date"
    t.string "sale_no"
    t.decimal "basis_amount", precision: 15, scale: 2, default: "0.0"
    t.string "commission_type", default: "percent"
    t.decimal "commission_value", precision: 15, scale: 2, default: "0.0"
    t.decimal "earned_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "paid_amount", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["agent_id"], name: "index_agent_commissions_on_agent_id"
    t.index ["branch_id"], name: "index_agent_commissions_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_agent_commissions_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_agent_commissions_on_business_id"
    t.index ["sale_id"], name: "index_agent_commissions_on_sale_id", unique: true
  end

  create_table "agents", force: :cascade do |t|
    t.string "name", null: false
    t.string "cnic"
    t.string "phone"
    t.string "city"
    t.text "address"
    t.string "commission_type", default: "percent"
    t.decimal "commission_amount", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_agents_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_agents_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_agents_on_business_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "business_id"
    t.bigint "branch_id"
    t.bigint "user_id"
    t.string "role"
    t.string "action", null: false
    t.string "record_type"
    t.bigint "record_id"
    t.bigint "subject_user_id"
    t.text "summary"
    t.jsonb "detail", default: {}, null: false
    t.string "request_method"
    t.string "request_path"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.index ["business_id", "created_at"], name: "index_audit_logs_on_business_id_and_created_at"
    t.index ["record_type", "record_id"], name: "index_audit_logs_on_record_type_and_record_id"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
  end

  create_table "branches", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "name", null: false
    t.string "code"
    t.string "branch_type", default: "main", null: false
    t.text "address"
    t.string "city"
    t.string "phone"
    t.string "status", default: "active", null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "provisioned_by_id"
    t.string "allowed_permissions", array: true
    t.index ["business_id", "name"], name: "index_branches_on_business_id_and_name", unique: true
    t.index ["business_id"], name: "index_branches_on_business_id"
    t.index ["provisioned_by_id"], name: "index_branches_on_provisioned_by_id"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_brands_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_brands_on_business_id_and_branch_id"
    t.index ["business_id", "name"], name: "index_brands_on_business_id_and_name", unique: true
    t.index ["business_id"], name: "index_brands_on_business_id"
  end

  create_table "businesses", force: :cascade do |t|
    t.string "name", null: false
    t.string "business_type", default: "Automobile Dealership"
    t.string "phone"
    t.text "address"
    t.string "city"
    t.string "cnic"
    t.string "ntn"
    t.string "logo_filename"
    t.string "currency", default: "PKR"
    t.integer "default_installment_day", default: 10
    t.string "late_fee_type", default: "none"
    t.decimal "late_fee_amount", precision: 15, scale: 2, default: "0.0"
    t.integer "low_stock_alert", default: 5
    t.boolean "allow_negative_stock", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "footer_text"
    t.string "status", default: "active", null: false
    t.bigint "provisioned_by_id"
    t.string "plan", default: "standard", null: false
    t.string "slug"
    t.index ["slug"], name: "index_businesses_on_slug", unique: true
    t.index ["status"], name: "index_businesses_on_status"
  end

  create_table "cash_book_entries", force: :cascade do |t|
    t.date "entry_date", null: false
    t.string "direction", null: false
    t.string "particulars"
    t.string "source_type"
    t.bigint "source_id"
    t.string "source_no"
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "payment_mode_id"
    t.bigint "account_id"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_cash_book_entries_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_cash_book_entries_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_cash_book_entries_on_business_id"
    t.index ["entry_date"], name: "index_cash_book_entries_on_entry_date"
    t.index ["source_type", "source_id"], name: "index_cash_book_entries_on_source_type_and_source_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "category_type", default: "vehicle", null: false
    t.string "serial_no"
    t.integer "warranty_months", default: 0
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_categories_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_categories_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_categories_on_business_id"
  end

  create_table "chart_of_accounts", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "account_type", null: false
    t.bigint "parent_id"
    t.boolean "is_cash_account", default: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_chart_of_accounts_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_chart_of_accounts_on_business_id_and_branch_id"
    t.index ["business_id", "code"], name: "index_chart_of_accounts_on_business_id_and_code", unique: true
    t.index ["business_id"], name: "index_chart_of_accounts_on_business_id"
    t.index ["parent_id"], name: "index_chart_of_accounts_on_parent_id"
  end

  create_table "credit_recoveries", force: :cascade do |t|
    t.date "recovery_date", null: false
    t.bigint "sale_id", null: false
    t.bigint "customer_id", null: false
    t.date "agreed_date"
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "payment_mode_id"
    t.string "reference"
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_credit_recoveries_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_credit_recoveries_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_credit_recoveries_on_business_id"
    t.index ["recovery_date"], name: "index_credit_recoveries_on_recovery_date"
    t.index ["sale_id"], name: "index_credit_recoveries_on_sale_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "account_no", null: false
    t.string "name", null: false
    t.string "father_name"
    t.string "cnic"
    t.string "phone"
    t.string "alt_phone"
    t.text "address"
    t.string "city"
    t.string "customer_type", default: "individual"
    t.string "business_name"
    t.string "email"
    t.decimal "credit_limit", precision: 15, scale: 2, default: "0.0"
    t.decimal "opening_balance", precision: 15, scale: 2, default: "0.0"
    t.bigint "agent_id"
    t.bigint "salesman_id"
    t.string "status", default: "active", null: false
    t.boolean "is_defaulter", default: false
    t.string "photo_filename"
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "location_id"
    t.bigint "business_id"
    t.index ["account_no"], name: "index_customers_on_account_no", unique: true
    t.index ["business_id"], name: "index_customers_on_business_id"
    t.index ["cnic"], name: "index_customers_on_cnic"
    t.index ["location_id"], name: "index_customers_on_location_id"
    t.index ["name"], name: "index_customers_on_name"
    t.index ["phone"], name: "index_customers_on_phone"
  end

  create_table "expense_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_expense_categories_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_expense_categories_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_expense_categories_on_business_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.date "expense_date", null: false
    t.bigint "category_id"
    t.string "description"
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "payment_mode_id"
    t.bigint "account_id"
    t.string "reference"
    t.bigint "added_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_expenses_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_expenses_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_expenses_on_business_id"
    t.index ["category_id"], name: "index_expenses_on_category_id"
    t.index ["expense_date"], name: "index_expenses_on_expense_date"
  end

  create_table "installment_payments", force: :cascade do |t|
    t.bigint "installment_plan_id"
    t.bigint "sale_id", null: false
    t.bigint "customer_id", null: false
    t.date "payment_date", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "late_fee", precision: 15, scale: 2, default: "0.0"
    t.boolean "is_short", default: false
    t.bigint "payment_mode_id"
    t.string "reference"
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "advance_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_installment_payments_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_installment_payments_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_installment_payments_on_business_id"
    t.index ["customer_id"], name: "index_installment_payments_on_customer_id"
    t.index ["payment_date"], name: "index_installment_payments_on_payment_date"
    t.index ["sale_id"], name: "index_installment_payments_on_sale_id"
  end

  create_table "installment_plans", force: :cascade do |t|
    t.bigint "sale_id", null: false
    t.integer "installment_no", null: false
    t.date "due_date", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "paid_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "short_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "late_fee", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "pending", null: false
    t.date "paid_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_installment_plans_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_installment_plans_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_installment_plans_on_business_id"
    t.index ["due_date"], name: "index_installment_plans_on_due_date"
    t.index ["sale_id"], name: "index_installment_plans_on_sale_id"
    t.index ["status"], name: "index_installment_plans_on_status"
  end

  create_table "installment_reminders", force: :cascade do |t|
    t.bigint "installment_plan_id", null: false
    t.bigint "sale_id"
    t.bigint "customer_id"
    t.string "channel", default: "sms"
    t.datetime "sent_at", default: -> { "CURRENT_TIMESTAMP" }
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_installment_reminders_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_installment_reminders_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_installment_reminders_on_business_id"
    t.index ["installment_plan_id"], name: "index_installment_reminders_on_installment_plan_id"
  end

  create_table "journal_voucher_lines", force: :cascade do |t|
    t.bigint "journal_voucher_id", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 15, scale: 2, default: "0.0"
    t.decimal "credit", precision: 15, scale: 2, default: "0.0"
    t.string "remarks"
    t.integer "line_no", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_journal_voucher_lines_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_journal_voucher_lines_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_journal_voucher_lines_on_business_id"
    t.index ["journal_voucher_id"], name: "index_journal_voucher_lines_on_journal_voucher_id"
  end

  create_table "journal_vouchers", force: :cascade do |t|
    t.string "voucher_no", null: false
    t.date "voucher_date", null: false
    t.string "description"
    t.decimal "total_amount", precision: 15, scale: 2, default: "0.0"
    t.string "reference"
    t.string "status", default: "posted", null: false
    t.bigint "posted_by_id"
    t.datetime "posted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_journal_vouchers_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_journal_vouchers_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_journal_vouchers_on_business_id"
    t.index ["voucher_no"], name: "index_journal_vouchers_on_voucher_no", unique: true
  end

  create_table "ledger_entries", comment: "Double-entry backbone. Every money movement writes one balanced pair.", force: :cascade do |t|
    t.date "entry_date", null: false
    t.bigint "account_id", null: false
    t.decimal "debit", precision: 15, scale: 2, default: "0.0"
    t.decimal "credit", precision: 15, scale: 2, default: "0.0"
    t.string "source_type"
    t.bigint "source_id"
    t.string "source_no"
    t.string "party_type"
    t.bigint "party_id"
    t.string "particulars"
    t.text "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["account_id"], name: "index_ledger_entries_on_account_id"
    t.index ["branch_id"], name: "index_ledger_entries_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_ledger_entries_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_ledger_entries_on_business_id"
    t.index ["entry_date"], name: "index_ledger_entries_on_entry_date"
    t.index ["party_type", "party_id"], name: "index_ledger_entries_on_party_type_and_party_id"
    t.index ["source_type", "source_id"], name: "index_ledger_entries_on_source_type_and_source_id"
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "business_id", null: false
    t.string "name", null: false
    t.string "city"
    t.string "zone"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["business_id", "name"], name: "index_locations_on_business_id_and_name", unique: true
    t.index ["business_id"], name: "index_locations_on_business_id"
  end

  create_table "payment_modes", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "is_cash", default: false
    t.string "status", default: "active"
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_payment_modes_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_payment_modes_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_payment_modes_on_business_id"
  end

  create_table "post_dated_cheques", force: :cascade do |t|
    t.string "cheque_no", null: false
    t.string "bank_name"
    t.bigint "customer_id", null: false
    t.bigint "sale_id"
    t.string "account_no"
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.date "cheque_date", null: false
    t.date "covered_month"
    t.string "status", default: "pending", null: false
    t.date "deposited_on"
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_post_dated_cheques_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_post_dated_cheques_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_post_dated_cheques_on_business_id"
    t.index ["cheque_no"], name: "index_post_dated_cheques_on_cheque_no"
    t.index ["status"], name: "index_post_dated_cheques_on_status"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_products_on_branch_id"
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["business_id", "branch_id"], name: "index_products_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_products_on_business_id"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["name"], name: "index_products_on_name"
  end

  create_table "purchase_items", force: :cascade do |t|
    t.bigint "purchase_id", null: false
    t.bigint "product_id"
    t.bigint "variant_id"
    t.string "description"
    t.decimal "qty", precision: 12, scale: 2, default: "1.0"
    t.decimal "unit_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "total", precision: 15, scale: 2, default: "0.0"
    t.boolean "create_stock_unit", default: true
    t.string "engine_no"
    t.string "chassis_no"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_purchase_items_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_purchase_items_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_purchase_items_on_business_id"
    t.index ["purchase_id"], name: "index_purchase_items_on_purchase_id"
  end

  create_table "purchase_payments", force: :cascade do |t|
    t.bigint "purchase_id", null: false
    t.date "payment_date", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "payment_mode_id"
    t.string "reference"
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_purchase_payments_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_purchase_payments_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_purchase_payments_on_business_id"
    t.index ["purchase_id"], name: "index_purchase_payments_on_purchase_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.string "purchase_no", null: false
    t.date "purchase_date", null: false
    t.bigint "supplier_id", null: false
    t.string "invoice_no"
    t.decimal "subtotal", precision: 15, scale: 2, default: "0.0"
    t.decimal "discount", precision: 15, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "paid_amount", precision: 15, scale: 2, default: "0.0"
    t.string "payment_type", default: "credit"
    t.bigint "payment_mode_id"
    t.string "status", default: "completed", null: false
    t.text "notes"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_purchases_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_purchases_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_purchases_on_business_id"
    t.index ["purchase_date"], name: "index_purchases_on_purchase_date"
    t.index ["purchase_no"], name: "index_purchases_on_purchase_no", unique: true
    t.index ["supplier_id"], name: "index_purchases_on_supplier_id"
  end

  create_table "quotation_plans", force: :cascade do |t|
    t.bigint "quotation_id", null: false
    t.integer "installment_no", null: false
    t.date "due_date", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_quotation_plans_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_quotation_plans_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_quotation_plans_on_business_id"
    t.index ["quotation_id"], name: "index_quotation_plans_on_quotation_id"
  end

  create_table "quotations", force: :cascade do |t|
    t.string "quotation_no", null: false
    t.date "quotation_date", null: false
    t.date "valid_until"
    t.bigint "customer_id"
    t.string "customer_name"
    t.string "customer_phone"
    t.bigint "product_id"
    t.bigint "variant_id"
    t.decimal "sale_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "down_payment", precision: 15, scale: 2, default: "0.0"
    t.integer "months", default: 0
    t.decimal "monthly_amount", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.bigint "converted_sale_id"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_quotations_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_quotations_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_quotations_on_business_id"
    t.index ["quotation_no"], name: "index_quotations_on_quotation_no", unique: true
    t.index ["status"], name: "index_quotations_on_status"
  end

  create_table "registration_trackings", force: :cascade do |t|
    t.bigint "sale_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "agent_id"
    t.string "engine_no"
    t.string "chassis_no"
    t.date "submitted_date"
    t.date "expected_return_date"
    t.boolean "letter_received", default: false
    t.date "received_date"
    t.string "status", default: "pending", null: false
    t.text "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_registration_trackings_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_registration_trackings_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_registration_trackings_on_business_id"
    t.index ["sale_id"], name: "index_registration_trackings_on_sale_id", unique: true
    t.index ["status"], name: "index_registration_trackings_on_status"
  end

  create_table "sale_items", force: :cascade do |t|
    t.bigint "sale_id", null: false
    t.bigint "product_id"
    t.bigint "variant_id"
    t.bigint "stock_unit_id"
    t.string "description"
    t.decimal "qty", precision: 12, scale: 2, default: "1.0"
    t.decimal "unit_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "discount", precision: 15, scale: 2, default: "0.0"
    t.decimal "total", precision: 15, scale: 2, default: "0.0"
    t.string "serial_no"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_sale_items_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_sale_items_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_sale_items_on_business_id"
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
  end

  create_table "sales", force: :cascade do |t|
    t.string "sale_no", null: false
    t.date "sale_date", null: false
    t.bigint "customer_id", null: false
    t.string "sale_type", default: "credit", null: false
    t.bigint "product_id"
    t.bigint "variant_id"
    t.bigint "stock_unit_id"
    t.string "reg_no"
    t.decimal "total_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "discount", precision: 15, scale: 2, default: "0.0"
    t.decimal "down_payment", precision: 15, scale: 2, default: "0.0"
    t.decimal "financed_amount", precision: 15, scale: 2, default: "0.0"
    t.integer "months", default: 0
    t.decimal "monthly_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "profit_amount", precision: 15, scale: 2, default: "0.0"
    t.bigint "payment_mode_id"
    t.bigint "agent_id"
    t.bigint "salesman_id"
    t.string "late_fee_type", default: "none"
    t.string "status", default: "completed", null: false
    t.text "notes"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "cost_amount", precision: 15, scale: 2, default: "0.0"
    t.boolean "is_advance_booking", default: false, null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_sales_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_sales_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_sales_on_business_id"
    t.index ["customer_id"], name: "index_sales_on_customer_id"
    t.index ["sale_date"], name: "index_sales_on_sale_date"
    t.index ["sale_no"], name: "index_sales_on_sale_no", unique: true
    t.index ["status"], name: "index_sales_on_status"
    t.index ["stock_unit_id"], name: "index_sales_on_stock_unit_id"
  end

  create_table "stock_units", force: :cascade do |t|
    t.bigint "product_id"
    t.bigint "variant_id"
    t.bigint "purchase_item_id"
    t.bigint "purchase_id"
    t.bigint "sale_id"
    t.bigint "supplier_id"
    t.string "engine_no"
    t.string "chassis_no"
    t.string "challan_no"
    t.string "reg_no"
    t.string "serial_no"
    t.string "biometric"
    t.string "file_location"
    t.string "colour"
    t.integer "warranty_months", default: 0
    t.date "warranty_expiry"
    t.decimal "cost_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "sale_price", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "available", null: false
    t.date "date_added", default: -> { "CURRENT_DATE" }
    t.date "sold_on"
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_stock_units_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_stock_units_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_stock_units_on_business_id"
    t.index ["chassis_no"], name: "index_stock_units_on_chassis_no"
    t.index ["engine_no"], name: "index_stock_units_on_engine_no"
    t.index ["product_id"], name: "index_stock_units_on_product_id"
    t.index ["status"], name: "index_stock_units_on_status"
    t.index ["variant_id"], name: "index_stock_units_on_variant_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.string "name", null: false
    t.string "city"
    t.string "phone"
    t.text "address"
    t.string "cnic"
    t.decimal "opening_balance", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_suppliers_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_suppliers_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_suppliers_on_business_id"
  end

  create_table "user_locations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_user_locations_on_location_id"
    t.index ["user_id", "location_id"], name: "index_user_locations_on_user_id_and_location_id", unique: true
    t.index ["user_id"], name: "index_user_locations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "full_name", null: false
    t.string "username", null: false
    t.string "password_digest", null: false
    t.string "role", default: "staff", null: false
    t.string "phone"
    t.string "status", default: "active", null: false
    t.datetime "last_login_at"
    t.boolean "must_change_password", default: false
    t.integer "failed_login_count", default: 0
    t.datetime "locked_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.bigint "customer_id"
    t.string "permissions_scope", default: "branch", null: false
    t.integer "provisioned_by_id"
    t.string "custom_permissions", array: true
    t.index ["branch_id"], name: "index_users_on_branch_id"
    t.index ["business_id"], name: "index_users_on_business_id"
    t.index ["customer_id"], name: "index_users_on_customer_id"
    t.index ["provisioned_by_id"], name: "index_users_on_provisioned_by_id"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "attribute_name", default: "Model"
    t.string "value", null: false
    t.decimal "purchase_price", precision: 15, scale: 2, default: "0.0"
    t.decimal "sale_price", precision: 15, scale: 2, default: "0.0"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_variants_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_variants_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_variants_on_business_id"
    t.index ["product_id"], name: "index_variants_on_product_id"
    t.index ["value"], name: "index_variants_on_value"
  end

  create_table "vehicle_documents", force: :cascade do |t|
    t.bigint "sale_id", null: false
    t.bigint "customer_id"
    t.string "document_type", null: false
    t.string "reference_no"
    t.boolean "received", default: false
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "expected_date"
    t.text "notes"
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_vehicle_documents_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_vehicle_documents_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_vehicle_documents_on_business_id"
    t.index ["document_type"], name: "index_vehicle_documents_on_document_type"
    t.index ["sale_id"], name: "index_vehicle_documents_on_sale_id"
  end

  create_table "vouchers", comment: "Receipt and payment vouchers share one table; kind is receipt|payment.", force: :cascade do |t|
    t.string "kind", null: false
    t.string "voucher_no", null: false
    t.date "voucher_date", null: false
    t.string "party_type"
    t.bigint "party_id"
    t.string "party_name"
    t.bigint "account_id"
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.bigint "payment_mode_id"
    t.string "reference"
    t.string "remarks"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_id"
    t.bigint "branch_id"
    t.index ["branch_id"], name: "index_vouchers_on_branch_id"
    t.index ["business_id", "branch_id"], name: "index_vouchers_on_business_id_and_branch_id"
    t.index ["business_id"], name: "index_vouchers_on_business_id"
    t.index ["party_type", "party_id"], name: "index_vouchers_on_party_type_and_party_id"
    t.index ["voucher_date"], name: "index_vouchers_on_voucher_date"
    t.index ["voucher_no", "kind"], name: "index_vouchers_on_voucher_no_and_kind", unique: true
  end

  add_foreign_key "account_closures", "customers"
  add_foreign_key "account_closures", "sales"
  add_foreign_key "account_transfers", "customers", column: "from_customer_id"
  add_foreign_key "account_transfers", "customers", column: "to_customer_id"
  add_foreign_key "advance_booking_payments", "advance_bookings"
  add_foreign_key "advance_booking_plans", "advance_bookings"
  add_foreign_key "advance_bookings", "customers"
  add_foreign_key "agent_commission_payments", "agent_commissions"
  add_foreign_key "agent_commissions", "agents"
  add_foreign_key "agent_commissions", "sales"
  add_foreign_key "branches", "businesses"
  add_foreign_key "credit_recoveries", "sales"
  add_foreign_key "customers", "agents"
  add_foreign_key "expenses", "expense_categories", column: "category_id"
  add_foreign_key "installment_payments", "installment_plans"
  add_foreign_key "installment_payments", "sales"
  add_foreign_key "installment_plans", "sales"
  add_foreign_key "installment_reminders", "installment_plans"
  add_foreign_key "journal_voucher_lines", "chart_of_accounts", column: "account_id"
  add_foreign_key "journal_voucher_lines", "journal_vouchers"
  add_foreign_key "ledger_entries", "chart_of_accounts", column: "account_id"
  add_foreign_key "ledger_entries", "users", column: "created_by_id"
  add_foreign_key "locations", "businesses"
  add_foreign_key "post_dated_cheques", "customers"
  add_foreign_key "products", "brands"
  add_foreign_key "products", "categories"
  add_foreign_key "purchase_items", "purchases"
  add_foreign_key "purchases", "suppliers"
  add_foreign_key "quotations", "customers"
  add_foreign_key "registration_trackings", "customers"
  add_foreign_key "registration_trackings", "sales"
  add_foreign_key "sale_items", "sales"
  add_foreign_key "sale_items", "stock_units"
  add_foreign_key "sales", "customers"
  add_foreign_key "sales", "payment_modes"
  add_foreign_key "sales", "users", column: "created_by_id"
  add_foreign_key "stock_units", "sales"
  add_foreign_key "stock_units", "variants"
  add_foreign_key "user_locations", "locations"
  add_foreign_key "user_locations", "users"
  add_foreign_key "users", "businesses"
  add_foreign_key "variants", "products"
  add_foreign_key "vehicle_documents", "sales"
  add_foreign_key "vouchers", "users", column: "created_by_id"
end

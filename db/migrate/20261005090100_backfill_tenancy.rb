# Backfills the tenant columns for the pre-existing (single shop) database and
# converts the legacy role names into the new permission model.
# Deliberately model-free so it runs before the new classes are loaded.
class BackfillTenancy < ActiveRecord::Migration[8.1]
  TABLES = %w[
    account_closures account_transfers advance_booking_payments advance_booking_plans
    advance_bookings agent_commission_payments agent_commissions agents brands
    cash_book_entries categories chart_of_accounts credit_recoveries customers
    expense_categories expenses installment_payments installment_plans
    installment_reminders journal_voucher_lines journal_vouchers ledger_entries
    payment_modes post_dated_cheques products purchase_items purchase_payments
    purchases quotation_plans quotations registration_trackings sale_items sales
    stock_units suppliers variants vehicle_documents vouchers locations
  ].freeze

  def up
    business_id = select_value("SELECT id FROM businesses ORDER BY id LIMIT 1")
    return if business_id.nil?

    slug = select_value("SELECT COALESCE(NULLIF(regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g'), ''), 'shop') FROM businesses WHERE id = #{business_id}")
    execute "UPDATE businesses SET status = 'active', plan = 'standard', slug = '#{slug}' WHERE id = #{business_id}"

    # One main branch for the existing shop.
    branch_id = select_value("SELECT id FROM branches WHERE business_id = #{business_id} AND branch_type = 'main' LIMIT 1")
    if branch_id.nil?
      execute <<~SQL
        INSERT INTO branches (business_id, name, code, branch_type, status, is_default, created_at, updated_at)
        VALUES (#{business_id}, 'Main Branch', 'MAIN', 'main', 'active', true, now(), now())
      SQL
      branch_id = select_value("SELECT id FROM branches WHERE business_id = #{business_id} ORDER BY id LIMIT 1")
    end

    # Default location so every existing customer is reachable by a recovery officer.
    location_id = select_value("SELECT id FROM locations WHERE business_id = #{business_id} ORDER BY id LIMIT 1")
    if location_id.nil?
      execute <<~SQL
        INSERT INTO locations (business_id, name, city, status, created_at, updated_at)
        VALUES (#{business_id}, 'All Locations', 'Unassigned', 'active', now(), now())
      SQL
      location_id = select_value("SELECT id FROM locations WHERE business_id = #{business_id} ORDER BY id LIMIT 1")
    end

    TABLES.each do |table|
      next unless table_exists?(table) && column_exists?(table, :business_id)

      execute "UPDATE #{table} SET business_id = #{business_id} WHERE business_id IS NULL"

      next unless column_exists?(table, :branch_id)
      next if %w[customers locations].include?(table)

      execute "UPDATE #{table} SET branch_id = #{branch_id} WHERE branch_id IS NULL"
    end

    # Customers are shop-wide; keep them on the default location.
    execute "UPDATE customers SET location_id = #{location_id} WHERE location_id IS NULL"

    # Legacy role names -> permission-model roles
    execute "UPDATE users SET role = 'shop_admin'    WHERE role = 'admin'"
    execute "UPDATE users SET role = 'branch_manager' WHERE role = 'manager'"
    execute "UPDATE users SET role = 'accountant'     WHERE role = 'accounts'"
    execute "UPDATE users SET role = 'cashier'        WHERE role = 'staff'"
    execute "UPDATE users SET branch_id = #{branch_id} WHERE branch_id IS NULL"
    execute "UPDATE users SET permissions_scope = 'business' WHERE role = 'shop_admin' AND permissions_scope <> 'business'"
  end

  def down
    execute "UPDATE users SET role = 'admin'   WHERE role = 'shop_admin'"
    execute "UPDATE users SET role = 'manager' WHERE role = 'branch_manager'"
    execute "UPDATE users SET role = 'accounts' WHERE role = 'accountant'"
    execute "UPDATE users SET role = 'staff'   WHERE role = 'cashier'"
  end
end

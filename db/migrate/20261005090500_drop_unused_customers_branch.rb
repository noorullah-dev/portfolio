# Customers are business-wide records that carry a single location_id; the
# branch_id column added by the original tenancy migration was never used and
# would only invite branch filtering that the UI does not expose.
class DropUnusedCustomersBranch < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:customers, :branch_id)

    remove_column :customers, :branch_id
  end

  def down
    add_column :customers, :branch_id, :integer
    add_index  :customers, :branch_id
  end
end

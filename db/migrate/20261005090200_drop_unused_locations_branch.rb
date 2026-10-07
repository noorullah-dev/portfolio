# Locations are a business-level concept (a recovery officer is assigned to a
# location, not to a branch), so the branch column added by the first pass of
# the tenancy migration is unused and misleading.
class DropUnusedLocationsBranch < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:locations, :branch_id)

    remove_index :locations, :branch_id if index_exists?(:locations, :branch_id)
    remove_index :locations, %i[business_id branch_id] if index_exists?(:locations, %i[business_id branch_id])
    remove_column :locations, :branch_id
  end

  def down
    add_column :locations, :branch_id, :integer
    add_index :locations, :branch_id
    add_index :locations, %i[business_id branch_id]
  end
end

# Records who created a branch, so a shop's structure is traceable.
class BranchProvisionedBy < ActiveRecord::Migration[8.1]
  def change
    add_column :branches, :provisioned_by_id, :integer
    add_index :branches, :provisioned_by_id
  end
end

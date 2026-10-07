class AddBranchStaffPermissions < ActiveRecord::Migration[8.1]
  def change
    # NULL keeps role defaults; an empty array intentionally grants no optional actions.
    add_column :branches, :allowed_permissions, :string, array: true
    add_column :users, :custom_permissions, :string, array: true
  end
end

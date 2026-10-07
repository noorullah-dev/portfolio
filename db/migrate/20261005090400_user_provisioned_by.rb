class UserProvisionedBy < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provisioned_by_id, :integer unless column_exists?(:users, :provisioned_by_id)
    add_index  :users, :provisioned_by_id unless index_exists?(:users, :provisioned_by_id)
  end
end

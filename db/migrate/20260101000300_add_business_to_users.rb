class AddBusinessToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :business_id, :bigint
    add_index :users, :business_id
    add_foreign_key :users, :businesses
  end
end
# Brands and chart of accounts are per-shop reference data, so their natural key
# is only unique inside a shop. Document numbers (sale_no, account_no, ...) stay
# globally unique on purpose: a number is quoted to customers and in support.
class TenantScopedUniqueIndexes < ActiveRecord::Migration[8.1]
  def up
    remove_index :brands, name: "index_brands_on_name" if index_name_exists?(:brands, "index_brands_on_name")
    add_index :brands, %i[business_id name], unique: true,
              name: "index_brands_on_business_id_and_name" unless index_exists?(:brands, %i[business_id name])

    remove_index :chart_of_accounts, name: "index_chart_of_accounts_on_code" if index_name_exists?(:chart_of_accounts, "index_chart_of_accounts_on_code")
    add_index :chart_of_accounts, %i[business_id code], unique: true,
              name: "index_chart_of_accounts_on_business_id_and_code" unless index_exists?(:chart_of_accounts, %i[business_id code])
  end

  def down
    remove_index :chart_of_accounts, name: "index_chart_of_accounts_on_business_id_and_code"
    add_index :chart_of_accounts, :code, unique: true
    remove_index :brands, name: "index_brands_on_business_id_and_name"
    add_index :brands, :name, unique: true
  end

  def index_name_exists?(table, name)
    connection.indexes(table).any? { |index| index.name == name }
  end
end

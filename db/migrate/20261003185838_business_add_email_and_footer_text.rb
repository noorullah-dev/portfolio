class BusinessAddEmailAndFooterText < ActiveRecord::Migration[8.1]
  def change
    add_column :businesses, :email, :string
    add_column :businesses, :footer_text, :string
  end
end
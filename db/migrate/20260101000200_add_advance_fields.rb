class AddAdvanceFields < ActiveRecord::Migration[8.1]
  def change
    add_column :installment_payments, :advance_amount,
               :decimal, precision: 15, scale: 2, default: 0, null: false
    add_column :sales, :cost_amount, :decimal, precision: 15, scale: 2, default: 0
    add_column :sales, :is_advance_booking, :boolean, default: false, null: false
    add_index :sales, :stock_unit_id
  end
end
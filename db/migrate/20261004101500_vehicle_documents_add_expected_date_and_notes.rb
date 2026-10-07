class VehicleDocumentsAddExpectedDateAndNotes < ActiveRecord::Migration[8.1]
  def change
    add_column :vehicle_documents, :expected_date, :date
    add_column :vehicle_documents, :notes, :text
  end
end
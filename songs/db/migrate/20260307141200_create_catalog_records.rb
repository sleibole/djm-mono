class CreateCatalogRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_records do |t|
      t.integer :catalog_id, null: false
      t.integer :user_id, null: false
      t.integer :status, null: false, default: 0
      t.integer :active_db_version
      t.text :error_details

      t.timestamps
    end
    add_index :catalog_records, :catalog_id, unique: true
  end
end

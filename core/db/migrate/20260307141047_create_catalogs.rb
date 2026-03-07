class CreateCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :catalogs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :catalogs, [ :user_id, :name ], unique: true
  end
end

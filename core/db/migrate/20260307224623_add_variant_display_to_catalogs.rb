class AddVariantDisplayToCatalogs < ActiveRecord::Migration[8.1]
  def change
    add_column :catalogs, :variant_display, :string, default: "none", null: false
  end
end

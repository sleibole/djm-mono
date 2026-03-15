class MakeCatalogIdNullableOnShows < ActiveRecord::Migration[8.1]
  def change
    change_column_null :shows, :catalog_id, true
  end
end

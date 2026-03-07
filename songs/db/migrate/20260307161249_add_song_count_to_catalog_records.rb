class AddSongCountToCatalogRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :catalog_records, :song_count, :integer
  end
end

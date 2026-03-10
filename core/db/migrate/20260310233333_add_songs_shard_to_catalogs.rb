class AddSongsShardToCatalogs < ActiveRecord::Migration[8.1]
  def change
    add_column :catalogs, :songs_shard, :integer, default: 1, null: false
  end
end

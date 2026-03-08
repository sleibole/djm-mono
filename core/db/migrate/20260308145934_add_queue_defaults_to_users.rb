class AddQueueDefaultsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_rotation_style, :string, default: "standard", null: false
    add_column :users, :default_show_type, :string, default: "karaoke", null: false
    add_column :users, :default_max_songs_per_singer, :integer
  end
end

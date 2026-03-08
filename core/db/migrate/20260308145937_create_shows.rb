class CreateShows < ActiveRecord::Migration[8.1]
  def change
    create_table :shows do |t|
      t.references :catalog, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :show_type, null: false, default: "karaoke"
      t.string :rotation_style, null: false, default: "standard"
      t.integer :max_songs_per_singer
      t.string :status, null: false, default: "active"
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end

    add_index :shows, [:user_id, :status]
  end
end

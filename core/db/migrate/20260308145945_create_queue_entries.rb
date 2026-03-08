class CreateQueueEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :queue_entries do |t|
      t.references :show, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true
      t.string :song_title, null: false
      t.string :song_artist, null: false
      t.string :song_version
      t.string :song_external_id
      t.integer :position, null: false
      t.string :status, null: false, default: "waiting"
      t.datetime :performed_at

      t.timestamps
    end

    add_index :queue_entries, [:show_id, :position]
    add_index :queue_entries, [:show_id, :status]
  end
end

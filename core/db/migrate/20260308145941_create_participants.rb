class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.string :name, null: false
      t.references :dj, null: false, foreign_key: { to_table: :users }
      t.references :user, foreign_key: true
      t.datetime :last_active_at

      t.timestamps
    end

    add_index :participants, [:dj_id, :name]
  end
end

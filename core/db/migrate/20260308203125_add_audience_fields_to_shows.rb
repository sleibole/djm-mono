class AddAudienceFieldsToShows < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :slug, :string
    add_column :shows, :approval_required, :boolean, default: true, null: false
    add_column :shows, :manual_entry_enabled, :boolean, default: false, null: false
    add_index :shows, [ :user_id, :slug ], unique: true
  end
end

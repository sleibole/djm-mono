class AddNameAndScheduledAtToShows < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :name, :string
    add_column :shows, :scheduled_at, :datetime
  end
end

class AddEmailStatusToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_status, :string, default: "active", null: false
    add_column :users, :email_status_reason, :string
    add_column :users, :last_delivered_at, :datetime
    add_column :users, :last_bounced_at, :datetime
    add_column :users, :last_complained_at, :datetime
  end
end

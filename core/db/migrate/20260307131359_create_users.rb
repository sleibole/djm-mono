class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest
      t.integer :role, null: false, default: 0
      t.datetime :email_confirmed_at
      t.integer :failed_login_attempts, null: false, default: 0
      t.datetime :locked_at

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end

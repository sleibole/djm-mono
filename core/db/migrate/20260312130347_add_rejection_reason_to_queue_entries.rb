class AddRejectionReasonToQueueEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :queue_entries, :rejection_reason, :string
  end
end

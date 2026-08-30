class AddGroupsSyncColumnsToWhatsappInstances < ActiveRecord::Migration[8.1]
  def change
    add_column :whatsapp_instances, :groups_synced_at, :datetime
    add_column :whatsapp_instances, :groups_sync_state, :integer, null: false, default: 0
    add_column :whatsapp_instances, :groups_sync_error, :string
  end
end

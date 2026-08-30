class CreateWhatsappGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_groups do |t|
      t.references :whatsapp_instance, null: false, foreign_key: true
      t.string   :remote_jid, null: false
      t.string   :subject
      t.boolean  :announce, null: false, default: false
      t.boolean  :active, null: false, default: true
      t.datetime :synced_at
      t.timestamps
    end
    add_index :whatsapp_groups, [ :whatsapp_instance_id, :remote_jid ], unique: true
    add_index :whatsapp_groups, [ :whatsapp_instance_id, :active ]
  end
end

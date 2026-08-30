class CreateWhatsappInstances < ActiveRecord::Migration[8.1]
  def change
    create_table :whatsapp_instances do |t|
      t.references :client, null: false, foreign_key: true, index: { unique: true }
      t.string   :instance_name,     null: false
      t.string   :remote_instance_id
      t.text     :token
      t.integer  :connection_state,  null: false, default: 0
      t.integer  :origin,            null: false, default: 0
      t.text     :last_qr_base64
      t.datetime :qr_expires_at
      t.datetime :paired_at
      t.datetime :last_checked_at
      t.text     :last_error
      t.timestamps
    end

    add_index :whatsapp_instances, :instance_name, unique: true
  end
end

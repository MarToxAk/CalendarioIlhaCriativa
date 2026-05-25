class CreateArtes < ActiveRecord::Migration[8.1]
  def change
    create_table :artes do |t|
      t.references :client, null: false, foreign_key: true
      t.string :title
      t.text :caption
      t.date :scheduled_on, null: false
      t.date :approval_deadline
      t.string :external_url
      t.integer :platform, null: false, default: 0
      t.integer :media_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :artes, [ :client_id, :scheduled_on ]
    add_index :artes, :status
  end
end

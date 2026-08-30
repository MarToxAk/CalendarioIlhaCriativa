class CreateDivulgacoes < ActiveRecord::Migration[8.1]
  def change
    create_table :divulgacoes do |t|
      t.references :client, null: false, foreign_key: true
      t.references :arte,   null: false, foreign_key: true
      t.datetime  :scheduled_for, null: false
      t.integer   :status, null: false, default: 0 # agendada:0 em_andamento:1 concluida:2 cancelada:3
      t.timestamps
    end
    add_index :divulgacoes, [ :client_id, :scheduled_for ]
  end
end

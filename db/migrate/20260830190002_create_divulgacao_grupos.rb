class CreateDivulgacaoGrupos < ActiveRecord::Migration[8.1]
  def change
    create_table :divulgacao_grupos do |t|
      t.references :divulgacao,     null: false, foreign_key: true
      t.references :whatsapp_group, null: false, foreign_key: true
      t.integer   :status, null: false, default: 0 # pendente:0 enviado:1 falhou:2 incerto:3
      t.string    :group_name, null: false # snapshot congelado de whatsapp_group.display_name na criacao (DIVU-09)
      t.string    :remote_jid, null: false # snapshot congelado de whatsapp_group.remote_jid na criacao (DIVU-09)
      # Colunas nulas encenadas para a fase 29 (motor de envio) — sem logica nesta fase.
      t.datetime  :sent_at
      t.string    :error_code
      t.string    :evolution_message_id
      t.timestamps
    end
    add_index :divulgacao_grupos, [ :divulgacao_id, :whatsapp_group_id ], unique: true
  end
end

class CreateApprovalResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_responses do |t|
      t.references :arte, null: false, foreign_key: true, index: { unique: true }
      t.integer :decision, null: false
      t.text :comment
      t.datetime :responded_at
      t.timestamps
    end

    add_index :approval_responses, :decision
  end
end

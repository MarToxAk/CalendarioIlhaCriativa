class AllowMultipleApprovalResponses < ActiveRecord::Migration[8.1]
  def change
    remove_index :approval_responses, :arte_id
    add_index :approval_responses, :arte_id
  end
end

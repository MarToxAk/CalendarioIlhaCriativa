class AddAdminReplyToArtes < ActiveRecord::Migration[8.1]
  def change
    add_column :artes, :admin_reply, :text
  end
end

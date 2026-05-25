class AddPasswordPlainToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :password_plain, :string
  end
end

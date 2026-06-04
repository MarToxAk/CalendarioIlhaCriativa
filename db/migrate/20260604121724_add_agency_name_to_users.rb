class AddAgencyNameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :agency_name, :string, null: false, default: "Ilha Criativa"
  end
end

class DeuniqueifyWhatsappInstanceName < ActiveRecord::Migration[8.1]
  def change
    remove_index :whatsapp_instances, :instance_name          # drops the unique index
    add_index    :whatsapp_instances, :instance_name          # recreate NON-unique — where(instance_name:) / find_by still indexed
  end
end

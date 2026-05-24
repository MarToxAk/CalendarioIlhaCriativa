# Admin user seed — idempotent via find_or_create_by!
# SECURITY: Em produção, use ENV.fetch("ADMIN_PASSWORD") em vez da senha hardcoded abaixo.
User.find_or_create_by!(email_address: "admin@ilhacriativa.com.br") do |u|
  u.password = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")
  u.password_confirmation = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")
end

puts "Seed concluído: #{User.count} admin(s) criado(s)."

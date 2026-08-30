# Boot-time timezone assertion — INFRA-03 (25-RESEARCH.md Pattern 4).
#
# config/application.rb pins config.time_zone = "Brasilia" and keeps
# config.active_record.default_timezone = :local (migrar para :utc é Out of Scope).
# :local só é seguro se o TZ do SO / container estiver fixo em America/Sao_Paulo —
# senão o mesmo datetime no banco significa horas diferentes entre dev e produção
# e um post agendado sai na hora errada (Pitfall 3). O horário de verão brasileiro
# está suspenso desde 2019, o que mascara o bug até uma troca de TZ do host.
#
# Discrição de Claude resolvida (25-RESEARCH.md Pattern 4 / 25-CONTEXT.md): raise em
# produção (um TZ errado publica na hora errada de forma irreversível — falhar no boot
# é mais barato), warn em development (o dev pode legitimamente estar noutro fuso).

# O Rails seta SECRET_KEY_BASE_DUMMY só durante `assets:precompile` / build da imagem
# (RAILS_ENV=production, sem TZ, sem config/master.key na imagem) — não é um boot real e
# o runtime dos containers (compose web/jobs, ./bin/rails server) nunca a seta. Pular a
# asserção de TZ aqui mantém o `docker compose build` vivo sem enfraquecer o boot check
# de produção real (CR-01 / 25-05).
return if ENV["SECRET_KEY_BASE_DUMMY"]

expected_tz   = "America/Sao_Paulo"
expected_zone = "Brasilia" # config.time_zone em config/application.rb

observed_tz   = ENV["TZ"]
observed_zone = Time.zone.name

ok = observed_tz == expected_tz && observed_zone == expected_zone

unless ok
  message = "Timezone não determinístico: ENV['TZ']=#{observed_tz.inspect} " \
            "(esperado #{expected_tz.inspect}), Time.zone=#{observed_zone.inspect} " \
            "(esperado #{expected_zone.inspect}). " \
            "config.active_record.default_timezone = :local exige um TZ fixo — ver INFRA-03."

  if Rails.env.production?
    raise(message)
  else
    Rails.logger.warn("[timezone_check] #{message}")
    # Também para $stderr: em development o Rails.logger vai só para log/development.log
    # quando rodado via bin/rails runner/console; o dev precisa ver o aviso no terminal.
    warn("[timezone_check] #{message}")
  end
end

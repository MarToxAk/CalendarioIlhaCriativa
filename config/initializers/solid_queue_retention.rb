# frozen_string_literal: true

# WR-01 (fase 30 REVIEW): SOLID_QUEUE_FAILED_RETENTION_DAYS era lido inline em
# config/recurring.yml via `Integer(ENV.fetch("SOLID_QUEUE_FAILED_RETENTION_DAYS",
# "14"))`. O `command:` de uma recurring task do solid_queue e avaliado com um
# `eval` bruto (vendor/.../solid_queue-1.4.0/app/jobs/solid_queue/recurring_job.rb)
# TODA vez que o job roda -- nao so no boot. Um valor invalido (ex.: "14d", string
# vazia por copy/paste de .env) so estourava ArgumentError la dentro, todo dia as
# 3h, desativando silenciosamente a retencao de solid_queue_failed_executions
# (INFRA-07) -- que guarda argumentos de job em texto claro -- sem nenhum sinal
# visivel alem de vasculhar os proprios failed_executions do job recorrente.
#
# Valida aqui, no boot, do mesmo jeito que Divulgacao::SEND_DELAY_MIN/MAX
# (app/models/divulgacao.rb:17-18) -- fail-fast uma vez (todo ambiente, pois
# `development:` tambem agenda esta task em config/recurring.yml), ao inves de
# falhar silenciosamente todo dia. `recurring.yml` chama
# SolidQueueRetention.failed_execution_days em vez de reimplementar o
# Integer(ENV.fetch(...)) inline.
module SolidQueueRetention
  def self.failed_execution_days
    Integer(ENV.fetch("SOLID_QUEUE_FAILED_RETENTION_DAYS", "14"))
  end
end

SolidQueueRetention.failed_execution_days

# frozen_string_literal: true

# Primeiro ActiveJob do repo (27-RESEARCH.md Pattern 4). Traduz a taxonomia
# Evolution::Errors em decisao de retry/discard: GET e idempotente, entao
# Transient/Unknown reenfileiram; o resto grava um codigo curto em
# groups_sync_error via mark_error e para. Estabelece o padrao para o motor
# de envio da fase 29.
class Whatsapp::SyncGroupsJob < ApplicationJob
  queue_as :default # config/queue.yml: worker unico em queues: "*", sem fila dedicada nesta fase (INFRA-06 e fase 29)

  # Fallback de ultima linha (27-REVIEW.md WR-A, re-review): qualquer excecao NAO listada
  # abaixo (StandardError alem da taxonomia Evolution::Errors::*) tambem tem que tirar
  # groups_sync_state de :syncing, senao o job falha cru, o estado fica preso em :syncing
  # para sempre, e o gate groups_sync_syncing? do WR-02 bloqueia TODO re-sync futuro dessa
  # instancia -- permanentemente, sem nenhuma affordance de recuperacao na UI.
  #
  # PRECISA ficar DECLARADO PRIMEIRO (antes de todo retry_on/discard_on mais especifico
  # abaixo). ActiveJob::Exceptions#handler_for_rescue busca em rescue_handlers.reverse_each
  # e usa o PRIMEIRO match -- ou seja, o handler mais RECENTEMENTE declarado tem prioridade
  # mais alta (doc oficial: "handlers are searched from bottom to top"). Um discard_on(StandardError)
  # declarado por ULTIMO venceria SEMPRE (StandardError é superclasse de Transient/Unknown/etc.),
  # engolindo os handlers especificos abaixo e quebrando os retries -- verificado empiricamente
  # (ver 27-REVIEW-FIX.md WR-A). Declarado PRIMEIRO, ele so roda quando nenhum handler mais
  # especifico (declarado depois) responde pela excecao.
  #
  # 27-REVIEW.md WR-1: este catch-all pega QUALQUER StandardError nao coberto acima --
  # nao so falhas reais da Evolution API, mas tambem bugs de programacao (nil inesperado,
  # falha de validacao em update!, formato de payload nao previsto). Codigo distinto
  # "unexpected_error" (em vez de reutilizar "transient") deixa claro pra quem depura via
  # groups_sync_error/Rails console que esse caminho e generico, nao uma falha de rede
  # conhecida -- e o Rails.logger.error com backtrace da o unico rastro disponivel, ja que
  # este repo nao tem integracao de error-tracking (Sentry/Honeybadger/etc.) configurada.
  discard_on(StandardError) do |job, err|
    Rails.logger.error(
      "[Whatsapp::SyncGroupsJob] erro inesperado (fora da taxonomia Evolution::Errors): " \
      "#{err.class}: #{err.message}\n#{err.backtrace&.first(10)&.join("\n")}"
    )
    mark_error(job, "unexpected_error")
  end

  # GET e idempotente -> ambos seguros para retry. Blocos disparam so apos as
  # 3 tentativas se esgotarem (comportamento padrao do ActiveJob) -- sem eles
  # o job re-levanta e groups_sync_state fica preso em :syncing para sempre,
  # ja que mark_error nunca roda (WR-01 do code review da fase 27).
  retry_on Evolution::Errors::Transient, wait: 30.seconds, attempts: 3 do |job, _err|
    mark_error(job, "transient")
  end
  retry_on Evolution::Errors::Unknown, wait: 30.seconds, attempts: 3 do |job, _err|
    mark_error(job, "transient")
  end

  # Retry nao resolve estes -> grava o motivo para a UI e para. Codigos distintos por classe
  # (27-REVIEW.md WR-03-DUP): "transient"/"permanent"/"config_error" nao podem colidir, senao
  # quem depura via groups_sync_error no Rails console (padrao que a fase 29 e instruida a
  # replicar) le "transient" para uma falha sistemica (400/404/422 de payload/rota, ou
  # ConfigurationError de boot) e perde a pista real. A UI (wa_groups_sync_error_message)
  # so tem copy dedicada para "not_connected" -- "permanent"/"config_error" caem de proposito
  # na mensagem generica de "tente de novo" (retry e instrucao valida pro usuario nos dois
  # casos), so o valor gravado no banco precisa ser preciso.
  discard_on(Evolution::Errors::Permanent)          { |job, _err| mark_error(job, "permanent") }
  discard_on(Evolution::Errors::NotConnected)       { |job, _err| mark_error(job, "not_connected") }
  discard_on(Evolution::Errors::ConfigurationError) { |job, _err| mark_error(job, "config_error") }
  discard_on(ActiveJob::DeserializationError) # instancia deletada mid-flight -- sem efeito colateral

  def perform(instance)
    Whatsapp::GroupSynchronizer.new(instance).call
  end

  def self.mark_error(job, code)
    inst = job.arguments.first
    inst.update!(groups_sync_state: :sync_error, groups_sync_error: code) if inst.is_a?(WhatsappInstance)
  end
end

# frozen_string_literal: true

# Primeiro ActiveJob do repo (27-RESEARCH.md Pattern 4). Traduz a taxonomia
# Evolution::Errors em decisao de retry/discard: GET e idempotente, entao
# Transient/Unknown reenfileiram; o resto grava um codigo curto em
# groups_sync_error via mark_error e para. Estabelece o padrao para o motor
# de envio da fase 29.
class Whatsapp::SyncGroupsJob < ApplicationJob
  queue_as :default # config/queue.yml: worker unico em queues: "*", sem fila dedicada nesta fase (INFRA-06 e fase 29)

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

  # Retry nao resolve estes -> grava o motivo para a UI e para.
  discard_on(Evolution::Errors::Permanent)          { |job, _err| mark_error(job, "transient") }
  discard_on(Evolution::Errors::NotConnected)       { |job, _err| mark_error(job, "not_connected") }
  discard_on(Evolution::Errors::ConfigurationError) { |job, _err| mark_error(job, "transient") }
  discard_on(ActiveJob::DeserializationError) # instancia deletada mid-flight -- sem efeito colateral

  def perform(instance)
    Whatsapp::GroupSynchronizer.new(instance).call
  end

  def self.mark_error(job, code)
    inst = job.arguments.first
    inst.update!(groups_sync_state: :sync_error, groups_sync_error: code) if inst.is_a?(WhatsappInstance)
  end
end

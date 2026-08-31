# frozen_string_literal: true

# Primeiro job do namespace Divulgacoes:: (fase 29, ENVIO-01). Agendado via
# `.set(wait_until: divulgacao.scheduled_for)` a partir de
# Admin::DivulgacoesController#create — nunca por scan periódico (CONTEXT.md
# resolvido). Lê os divulgacao_grupos pendentes e enfileira um
# Whatsapp::SendToGroupJob por grupo, com offset crescente de espera
# (Divulgacao::SEND_DELAY_MIN/MAX) — nunca um wait bloqueante, o worker fica
# livre entre grupos (ENVIO-03). Forma final desde este plano: o plano 29-03 só adiciona
# testes de escalonamento com múltiplos grupos, não muda este método.
class Divulgacoes::DispatchJob < ApplicationJob
  queue_as :whatsapp_sends # config/queue.yml: worker "*" genérico pega até a fila dedicada chegar no 29-03 (INFRA-06)

  def perform(divulgacao)
    divulgacao.reload
    return if divulgacao.status_cancelada?

    divulgacao.update!(status: :em_andamento) if divulgacao.status_agendada?

    offset = 0
    divulgacao.divulgacao_grupos.pendente.find_each do |group|
      Whatsapp::SendToGroupJob.set(wait: offset.seconds).perform_later(group)
      offset += rand(Divulgacao::SEND_DELAY_MIN..Divulgacao::SEND_DELAY_MAX)
    end
  end
end

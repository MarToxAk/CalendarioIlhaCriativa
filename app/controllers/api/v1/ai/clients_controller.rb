# frozen_string_literal: true

class Api::V1::Ai::ClientsController < Api::V1::Ai::BaseController
  def summary
    # D-11: RecordNotFound automático → 404 via rescue_from herdado (T-24-07)
    client = Client.find(params[:id])

    counts = Arte.where(client_id: client.id).group(:status).count

    total                  = counts.values.sum
    approved_count         = counts["approved"].to_i
    pending_count          = counts["pending"].to_i
    change_requested_count = counts["change_requested"].to_i
    revised_count          = counts["revised"].to_i

    render_envelope(data: {
      client_id:             client.id,
      total:,
      approved_count:,
      pending_count:,
      change_requested_count:,
      revised_count:
    })
  end
end

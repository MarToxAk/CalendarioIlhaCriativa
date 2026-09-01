# frozen_string_literal: true

class Api::V1::BaseController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound,        with: :not_found
  rescue_from ActiveRecord::RecordInvalid,         with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing,  with: :bad_request

  private

  def render_envelope(data:, meta: {}, status: :ok)
    render json: { data: data, meta: meta, errors: [] }, status: status
  end

  def render_error(code:, detail:, status:, field: nil)
    error = { code: code, detail: detail }
    error[:field] = field if field
    render json: { data: nil, meta: {}, errors: [ error ] }, status: status
  end

  def not_found
    render_error(code: "not_found", detail: "Recurso não encontrado", status: :not_found)
  end

  def unprocessable_entity(exception)
    errors = exception.record.errors.map do |e|
      { code: "validation_error", detail: e.full_message, field: e.attribute.to_s }
    end
    render json: { data: nil, meta: {}, errors: errors }, status: :unprocessable_entity
  end

  def bad_request(exception)
    render_error(code: "bad_request", detail: exception.message, status: :bad_request)
  end
end

# frozen_string_literal: true

require "test_helper"

class Api::V1::Ai::DocsControllerTest < ActionDispatch::IntegrationTest
  AI_API_KEY = "ak_test_#{SecureRandom.hex(8)}"

  setup do
    @original_ai_key = ENV["AI_API_KEY"]
    ENV["AI_API_KEY"] = AI_API_KEY
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
  end

  teardown do
    ENV["AI_API_KEY"] = @original_ai_key
  end

  test "GET /docs sem chave retorna 401" do
    get "/api/v1/ai/docs"
    assert_response :unauthorized
  end

  test "GET /docs com chave retorna o markdown da documentacao" do
    get "/api/v1/ai/docs", headers: { "Authorization" => "Bearer #{AI_API_KEY}" }

    assert_response :success
    assert_includes response.content_type, "text/markdown"
    assert_includes response.body, "# API de IA"
    assert_includes response.body, "POST /divulgacoes"
  end

  test "a documentacao cita todas as rotas de IA registradas" do
    doc = Api::V1::Ai::DocsController::DOC_PATH.read

    ai_routes = Rails.application.routes.routes.filter_map do |r|
      path = r.path.spec.to_s
      next unless path.start_with?("/api/v1/ai/") && path != "/api/v1/ai/docs(.:format)"

      verb = r.verb.to_s
      route = path.delete_prefix("/api/v1/ai").delete_suffix("(.:format)")
      [ verb, route ]
    end

    assert_operator ai_routes.size, :>=, 8
    ai_routes.each do |verb, route|
      assert_includes doc, "#{verb} #{route}", "docs/api-ia.md nao documenta #{verb} #{route}"
    end
  end
end

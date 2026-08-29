# frozen_string_literal: true

require "test_helper"

# Cobertura da taxonomia de erro / timeout / logging seguro de Evolution::Client
# (EVO-03). Usa Faraday::Adapter::Test — in-process, sem rede e sem banco.
# Nota deste ambiente: `bin/rails test` completo não roda (o banco de teste
# pertence a outro usuário do SO); a verificação canônica é o runner de
# `25-01-PLAN.md` (<verify>). Este arquivo documenta os casos e roda isolado.
class Evolution::ClientTest < ActiveSupport::TestCase
  # Conexão Faraday com o MESMO stack de middleware do Client, mas adapter :test.
  def stubbed_connection(status, body, headers = { "Content-Type" => "application/json" }, path: "/x")
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.get(path) { [ status, headers, body ] }
    end
    Faraday.new do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, stubs
    end
  end

  def response_for(status, body, headers = { "Content-Type" => "application/json" })
    stubbed_connection(status, body, headers).get("/x")
  end

  def assert_raises_for(klass, status, body, headers = { "Content-Type" => "application/json" })
    error = assert_raises(klass) do
      Evolution::Client.send(:raise_for_status!, response_for(status, body, headers))
    end
    error
  end

  # --- 5xx → Transient -------------------------------------------------------
  test "503/500/502/504 with any JSON body classify as Transient" do
    [ 500, 502, 503, 504 ].each do |code|
      assert_raises_for(Evolution::Errors::Transient, code, "{}")
    end
  end

  test "408 and 429 classify as Transient" do
    assert_raises_for(Evolution::Errors::Transient, 408, "{}")
    assert_raises_for(Evolution::Errors::Transient, 429, "{}")
  end

  # --- 4xx → Permanent -----------------------------------------------------
  test "401 and 403 classify as Permanent" do
    assert_raises_for(Evolution::Errors::Permanent, 401,
                      '{"status":401,"error":"Unauthorized","response":{"message":"Unauthorized"}}')
    assert_raises_for(Evolution::Errors::Permanent, 403, "{}")
  end

  test "400/404/422 classify as Permanent" do
    assert_raises_for(Evolution::Errors::Permanent, 400, "{}")
    assert_raises_for(Evolution::Errors::Permanent, 404,
                      '{"status":404,"error":"Not Found","response":{"message":["Cannot GET /x"]}}')
    assert_raises_for(Evolution::Errors::Permanent, 422, "{}")
  end

  # --- 5xx não-JSON (Cloudflare HTML) → Transient, sem ecoar o HTML ---------
  test "5xx with non-JSON HTML body is Transient and does not echo the HTML" do
    html = "<html><body>cloudflare error 502 ray id abc</body></html>"
    error = assert_raises_for(Evolution::Errors::Transient, 502, html, { "Content-Type" => "text/html" })
    refute_includes error.message, "cloudflare"
    refute_includes error.message, "<html>"
  end

  # --- response.message String vs Array -----------------------------------
  test "response.message is parsed whether String or Array" do
    str = assert_raises_for(Evolution::Errors::Permanent, 401,
                            '{"response":{"message":"Unauthorized"}}')
    assert_includes str.message, "Unauthorized"

    arr = assert_raises_for(Evolution::Errors::Permanent, 404,
                            '{"response":{"message":["Cannot GET /x","and more"]}}')
    assert_includes arr.message, "Cannot GET /x"
    assert_includes arr.message, "and more"
  end

  # --- classify_timeout: connect-phase vs read-phase ----------------------
  test "connect-phase timeout classifies as Transient" do
    err = Faraday::TimeoutError.new(Net::OpenTimeout.new("execution expired"))
    assert_equal Evolution::Errors::Transient, Evolution::Client.send(:classify_timeout, err)
  end

  test "read-phase timeout classifies as Unknown" do
    err = Faraday::TimeoutError.new(Net::ReadTimeout.new)
    assert_equal Evolution::Errors::Unknown, Evolution::Client.send(:classify_timeout, err)
  end

  test "undistinguishable Faraday::TimeoutError defaults to Unknown" do
    err = Faraday::TimeoutError.new("timeout")
    assert_equal Evolution::Errors::Unknown, Evolution::Client.send(:classify_timeout, err)
  end

  # --- assert_open! ------------------------------------------------------
  test "assert_open! is silent for state open" do
    assert_nil Evolution::Client.assert_open!("open")
  end

  test "assert_open! raises NotConnected for any non-open state" do
    %w[connecting close].each do |state|
      assert_raises(Evolution::Errors::NotConnected) { Evolution::Client.assert_open!(state) }
    end
  end

  # --- 2xx passes through ----------------------------------------------
  test "raise_for_status! is silent on a 2xx response" do
    assert_nil Evolution::Client.send(:raise_for_status!, response_for(200, "{}"))
  end

  # --- logging carries metadata only, never the apikey ------------------
  test "successful request logs method/path/status/duration and not the apikey" do
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    Evolution::Client.instance_variable_set(
      :@connection,
      stubbed_connection(200, '{"ok":true}', path: "/instance/fetchInstances")
    )

    Evolution::Client.fetch_instances(api_key: "super-secret-apikey-value")

    log = io.string
    assert_match(%r{\[evolution\] GET \S+ -> 200 \(\d+ms\)}, log)
    refute_includes log, "super-secret-apikey-value"
    refute_includes log, "apikey"
  ensure
    Rails.logger = original
    Evolution::Client.instance_variable_set(:@connection, nil)
  end
end

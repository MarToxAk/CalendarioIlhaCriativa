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

  # POST variant of stubbed_connection — usada pelos testes de create_instance
  # (26-01). Mesmo stack de middleware do Client, adapter :test.
  def stubbed_post_connection(status, body, headers = { "Content-Type" => "application/json" }, path: "/instance/create")
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.post(path) { [ status, headers, body ] }
    end
    Faraday.new do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, stubs
    end
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
    # WR-07 (25-05): fetch_instances agora exige corpo Array num 2xx — um Hash/String
    # vira Evolution::Errors::Unknown. O stub aqui só existe para exercitar o log seguro,
    # então um array vazio serve.
    Evolution::Client.instance_variable_set(
      :@connection,
      stubbed_connection(200, "[]", path: "/instance/fetchInstances")
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

  # --- create_instance (PAIR-01, 26-01) -----------------------------------
  test "create_instance returns the response body on a 2xx with a Hash" do
    body = { "instance" => { "instanceId" => "abc-123" }, "hash" => "raw-instance-token", "qrcode" => { "base64" => "data:image/png;base64,xyz" } }
    Evolution::Client.instance_variable_set(:@connection, stubbed_post_connection(201, body.to_json))

    resp = Evolution::Client.create_instance(
      instance_name: "livia_client_1",
      webhook_url: "https://example.com/webhooks/evolution",
      webhook_headers: { "X-Webhook-Secret" => "hmac-value" },
      api_key: "test-api-key"
    )

    assert_equal "abc-123", resp.dig("instance", "instanceId")
    assert_equal "raw-instance-token", resp["hash"]
    assert_equal "data:image/png;base64,xyz", resp.dig("qrcode", "base64")
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "create_instance raises Unknown when the 2xx body is not a Hash" do
    Evolution::Client.instance_variable_set(:@connection, stubbed_post_connection(200, "[]"))

    assert_raises(Evolution::Errors::Unknown) do
      Evolution::Client.create_instance(
        instance_name: "livia_client_1",
        webhook_url: "https://example.com/webhooks/evolution",
        webhook_headers: {},
        api_key: "test-api-key"
      )
    end
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "create_instance raises Permanent matching /already in use/i on a 403 name collision" do
    body = { "status" => 403, "error" => "Forbidden", "response" => { "message" => 'This name "livia_client_1" is already in use.' } }.to_json
    Evolution::Client.instance_variable_set(:@connection, stubbed_post_connection(403, body))

    error = assert_raises(Evolution::Errors::Permanent) do
      Evolution::Client.create_instance(
        instance_name: "livia_client_1",
        webhook_url: "https://example.com/webhooks/evolution",
        webhook_headers: {},
        api_key: "test-api-key"
      )
    end
    assert_match(/already in use/i, error.message)
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  # --- connect / set_webhook (PAIR-02, 26-02) ------------------------------
  test "connect returns a normalized Hash on a 2xx with a valid QR" do
    body = { "base64" => "data:image/png;base64,qr", "code" => "2@abc", "pairingCode" => "ABCD1234", "count" => 1 }.to_json
    Evolution::Client.instance_variable_set(
      :@connection, stubbed_connection(200, body, path: "/instance/connect/livia_client_1")
    )

    resp = Evolution::Client.connect("livia_client_1", api_key: "test-api-key")

    assert_equal "data:image/png;base64,qr", resp[:base64]
    assert_equal "2@abc", resp[:code]
    assert_equal "ABCD1234", resp[:pairing_code]
    assert_equal 1, resp[:count]
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "connect normalizes a QR nested under the qrcode key" do
    body = { "qrcode" => { "base64" => "data:image/png;base64,nested", "code" => "2@nested", "count" => 2 } }.to_json
    Evolution::Client.instance_variable_set(
      :@connection, stubbed_connection(200, body, path: "/instance/connect/livia_client_1")
    )

    resp = Evolution::Client.connect("livia_client_1", api_key: "test-api-key")

    assert_equal "data:image/png;base64,nested", resp[:base64]
    assert_equal "2@nested", resp[:code]
    assert_equal 2, resp[:count]
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "connect raises Transient when the 2xx body has error=true (Pitfall 6)" do
    body = { "error" => true, "message" => "The instance does not exist" }.to_json
    Evolution::Client.instance_variable_set(
      :@connection, stubbed_connection(200, body, path: "/instance/connect/livia_client_1")
    )

    error = assert_raises(Evolution::Errors::Transient) do
      Evolution::Client.connect("livia_client_1", api_key: "test-api-key")
    end
    refute_includes error.message, "does not exist"
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "connect raises Unknown when the 2xx body is not a Hash" do
    Evolution::Client.instance_variable_set(
      :@connection, stubbed_connection(200, "[]", path: "/instance/connect/livia_client_1")
    )

    assert_raises(Evolution::Errors::Unknown) do
      Evolution::Client.connect("livia_client_1", api_key: "test-api-key")
    end
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "set_webhook returns the response body on a 201" do
    body = { "webhook" => { "enabled" => true } }.to_json
    Evolution::Client.instance_variable_set(
      :@connection, stubbed_post_connection(201, body, path: "/webhook/set/livia_client_1")
    )

    resp = Evolution::Client.set_webhook(
      "livia_client_1",
      url: "https://example.com/webhooks/evolution",
      headers: { "X-Webhook-Secret" => "hmac-value" },
      api_key: "test-api-key"
    )

    assert_equal true, resp.dig("webhook", "enabled")
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  # --- fetch_groups (fase 27, GRUPO-01) ------------------------------------
  test "fetch_groups returns the Array body on a 200" do
    body = [ { "id" => "1@g.us", "subject" => "Grupo A" } ].to_json
    Evolution::Client.instance_variable_set(
      :@connection,
      stubbed_connection(200, body, path: "/group/fetchAllGroups/livia_client_1?getParticipants=false")
    )

    resp = Evolution::Client.fetch_groups("livia_client_1", api_key: "test-api-key")

    assert_equal 1, resp.size
    assert_equal "1@g.us", resp.first["id"]
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "fetch_groups raises Unknown when the 2xx body is a Hash (not an Array)" do
    Evolution::Client.instance_variable_set(
      :@connection,
      stubbed_connection(200, "{}", path: "/group/fetchAllGroups/livia_client_1?getParticipants=false")
    )

    error = assert_raises(Evolution::Errors::Unknown) do
      Evolution::Client.fetch_groups("livia_client_1", api_key: "test-api-key")
    end
    refute_includes error.message, "{}"
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "fetch_groups raises Unknown when the 2xx body is HTML (Cloudflare interstitial)" do
    html = "<html><body>cloudflare check</body></html>"
    Evolution::Client.instance_variable_set(
      :@connection,
      stubbed_connection(200, html, { "Content-Type" => "text/html" },
                          path: "/group/fetchAllGroups/livia_client_1?getParticipants=false")
    )

    assert_raises(Evolution::Errors::Unknown) do
      Evolution::Client.fetch_groups("livia_client_1", api_key: "test-api-key")
    end
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  # 27-REVIEW.md WR-A (re-review): antes desta cobertura, um 200 com Content-Type json e
  # corpo malformado fazia o middleware :json do Faraday levantar Faraday::ParsingError, que
  # NÃO era um Faraday::ConnectionFailed/TimeoutError -- escapava cru de #request, o
  # SyncGroupsJob nunca rodava retry_on/discard_on, e groups_sync_state ficava preso em
  # :syncing para sempre (reproduzido empiricamente no code review). Agora todo
  # Faraday::Error residual vira Evolution::Errors::Unknown, que já está coberto por
  # retry_on no job.
  test "fetch_groups raises Unknown (not a raw Faraday::ParsingError) when the 2xx body is malformed JSON with a json Content-Type" do
    Evolution::Client.instance_variable_set(
      :@connection,
      stubbed_connection(200, "not json{", path: "/group/fetchAllGroups/livia_client_1?getParticipants=false")
    )

    error = assert_raises(Evolution::Errors::Unknown) do
      Evolution::Client.fetch_groups("livia_client_1", api_key: "test-api-key")
    end
    assert_kind_of Evolution::Errors::Unknown, error
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "fetch_groups surfaces a 400 (missing/invalid getParticipants) as Permanent" do
    body = { "status" => 400, "error" => "Bad Request", "response" => { "message" => "getParticipants is required" } }.to_json
    Evolution::Client.instance_variable_set(
      :@connection,
      stubbed_connection(400, body, path: "/group/fetchAllGroups/livia_client_1?getParticipants=false")
    )

    assert_raises(Evolution::Errors::Permanent) do
      Evolution::Client.fetch_groups("livia_client_1", api_key: "test-api-key")
    end
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "fetch_groups sends getParticipants=false in the query string" do
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.get("/group/fetchAllGroups/livia_client_1?getParticipants=false") do |_env|
        [ 200, { "Content-Type" => "application/json" }, "[]" ]
      end
    end
    Evolution::Client.instance_variable_set(
      :@connection,
      Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.adapter :test, stubs
      end
    )

    assert_equal [], Evolution::Client.fetch_groups("livia_client_1", api_key: "test-api-key")
    stubs.verify_stubbed_calls
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end

  test "fetch_groups api_key: per call overrides the memoized global apikey header" do
    stubs = Faraday::Adapter::Test::Stubs.new do |s|
      s.get("/group/fetchAllGroups/livia_client_1?getParticipants=false") do |env|
        [ 200, { "Content-Type" => "application/json" }, [ { "id" => env.request_headers["apikey"] } ].to_json ]
      end
    end
    Evolution::Client.instance_variable_set(
      :@connection,
      Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.headers["apikey"] = "global-apikey-value"
        f.adapter :test, stubs
      end
    )

    resp = Evolution::Client.fetch_groups("livia_client_1", api_key: "instance-token-value")

    assert_equal "instance-token-value", resp.first["id"]
  ensure
    Evolution::Client.instance_variable_set(:@connection, nil)
  end
end

# frozen_string_literal: true

require "net/http" # Net::OpenTimeout / Net::ReadTimeout — usados por classify_timeout

module Evolution
  # A ÚNICA costura HTTP entre este app e o host Evolution da agência, para todas
  # as fases 25–30 (EVO-02). PORO com métodos de classe, espelhando
  # app/services/api/jwt_service.rb.
  #
  # Contrato verificado empiricamente em .planning/notes/evolution-contract.md
  # (2026-08-29, host = Evolution API 2.3.7 atrás de Cloudflare). Ver também
  # 25-RESEARCH.md Pattern 2 / Pattern 3.
  #
  # Invariantes:
  #   - autenticação SÓ pelo header `apikey` (Authorization: Bearer → 401 verificado);
  #   - timeouts open/write/read explícitos vindos de config/initializers/evolution.rb;
  #   - nenhuma Faraday::Error nem status HTTP cru escapa — tudo vira Evolution::Errors::*;
  #   - o log de request carrega método, path, status e duração APENAS — nunca corpo,
  #     headers, apikey, hash ou QR base64.
  class Client
    class << self
      # Faraday::Connection memoizada: base_url + header apikey global + 3 timeouts.
      def connection
        @connection ||= Faraday.new(url: Evolution.base_url) do |f|
          f.request :json
          f.response :json, content_type: /\bjson$/
          f.headers["apikey"] = Evolution.global_api_key
          f.options.open_timeout  = Evolution::OPEN_TIMEOUT
          f.options.write_timeout = Evolution::WRITE_TIMEOUT
          f.options.read_timeout  = Evolution::READ_TIMEOUT
          f.adapter Faraday.default_adapter
        end
      end

      # POST /instance/create — instanceName vai no CORPO, sem path param (única
      # exceção de rota da fase). Retorna o Hash do corpo num 2xx. 403 "already in
      # use" sobe como Evolution::Errors::Permanent (raise_for_status! já mapeia
      # 403 -> Permanent) — o chamador (InstanceProvisioner) rescue + casa
      # /already in use/i (adoção chega no plano 26-02; aqui só propaga).
      def create_instance(instance_name:, webhook_url:, webhook_headers:, events: %w[QRCODE_UPDATED CONNECTION_UPDATE], number: nil, api_key: Evolution.global_api_key)
        body = {
          instanceName: instance_name,
          integration: "WHATSAPP-BAILEYS",
          qrcode: true,
          webhook: {
            enabled: true,
            url: webhook_url,
            byEvents: false,
            base64: true,
            events: events,
            headers: webhook_headers
          }
        }
        body[:number] = number if number.present?
        resp = request(:post, "/instance/create", api_key: api_key, body: body)
        raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless resp.body.is_a?(Hash)

        resp.body
      end

      # GET /instance/connect/{instance} — devolve o QR corrente. Pitfall 6 do
      # RESEARCH: em alguns builds devolve HTTP 200 com { "error": true, "message":
      # "..." } em vez de um QR — NUNCA tratar esse corpo como QR válido.
      def connect(instance_name, api_key: Evolution.global_api_key)
        resp = request(:get, "/instance/connect/#{instance_name}",
                       api_key: api_key, read_timeout: Evolution::READ_TIMEOUT_FAST)
        body = resp.body
        raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless body.is_a?(Hash)
        raise Evolution::Errors::Transient, "connect retornou error=true" if body["error"]

        # normaliza: aceita tanto chaves top-level quanto aninhadas em "qrcode"
        {
          base64: body["base64"] || body.dig("qrcode", "base64"),
          code: body["code"] || body.dig("qrcode", "code"),
          pairing_code: body["pairingCode"] || body.dig("qrcode", "pairingCode"),
          count: body["count"] || body.dig("qrcode", "count")
        }
      end

      # POST /webhook/set/{instance} — reaponta o webhook (usado incondicionalmente
      # na adoção — Pitfall 4). `events` é SEMPRE explícito: um array vazio faz o
      # Evolution trocar por "todos os eventos". Retorna o body do 201.
      def set_webhook(instance_name, url:, headers:, events: %w[QRCODE_UPDATED CONNECTION_UPDATE], api_key: Evolution.global_api_key)
        body = { webhook: { enabled: true, url: url, byEvents: false, base64: true, events: events, headers: headers } }
        request(:post, "/webhook/set/#{instance_name}", api_key: api_key, body: body).body
      end

      # GET /instance/fetchInstances — leitura rápida. Retorna o corpo (Array).
      def fetch_instances(api_key: Evolution.global_api_key)
        body = request(:get, "/instance/fetchInstances",
                       api_key: api_key, read_timeout: Evolution::READ_TIMEOUT_FAST).body
        # WR-07 / SC3: um 2xx com corpo não-JSON (interstitial HTML da Cloudflare) chega
        # aqui como String — classificar como incerto em vez de deixar um TypeError cru
        # escapar. Mensagem estática: o corpo (HTML da CF) nunca é interpolado.
        raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless body.is_a?(Array)

        body
      end

      # GET /instance/connectionState/{instance} — retorna a string crua
      # "open" / "connecting" / "close". Levantar NotConnected é papel do chamador
      # (fase 29); use assert_open! quando quiser transformar em erro.
      def connection_state(instance_name, api_key: Evolution.global_api_key)
        resp = request(:get, "/instance/connectionState/#{instance_name}",
                       api_key: api_key, read_timeout: Evolution::READ_TIMEOUT_FAST)
        # WR-07 / SC3: idem fetch_instances — só seguir com o .dig quando o corpo é mesmo
        # um Hash JSON; um 2xx não-JSON vira Unknown com mensagem estática (sem ecoar o body).
        raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless resp.body.is_a?(Hash)

        resp.body.dig("instance", "state")
      end

      # Transforma um estado de conexão que não seja "open" em NotConnected.
      # Silencioso (retorna nil) quando o estado é "open".
      def assert_open!(state)
        return if state == "open"

        raise Evolution::Errors::NotConnected, "instância não conectada (state=#{state.inspect})"
      end

      # GET /group/fetchAllGroups/{instance}?getParticipants=false — leitura de
      # grupos da instância (fase 27, GRUPO-01). `getParticipants` é OBRIGATÓRIO
      # como string (senão 400 -> Evolution::Errors::Permanent). Usa o TOKEN DA
      # INSTÂNCIA (api_key: whatsapp_instance.token), não a apikey global. Espelha
      # fetch_instances, inclusive o guard WR-07.
      def fetch_groups(instance_name, api_key:)
        body = request(:get, "/group/fetchAllGroups/#{instance_name}",
                       api_key: api_key,
                       query: { "getParticipants" => "false" },
                       read_timeout: Evolution::READ_TIMEOUT_FAST).body
        raise Evolution::Errors::Unknown, "resposta 2xx com corpo não-JSON do host Evolution" unless body.is_a?(Array)

        body
      end

      private

      def request(method, path, api_key:, body: nil, read_timeout: nil, query: nil)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        resp = nil
        resp = connection.public_send(method, path) do |req|
          req.headers["apikey"] = api_key
          req.params.update(query) if query
          # WR-01: setar a chave `read_timeout` (não `timeout`) — o Faraday resolve
          # `options[:read_timeout]` ANTES de `options[:timeout]` em `request_timeout(:read, ...)`,
          # então o valor rápido (15s) deixa de ser sombreado pelos 30s da conexão memoizada.
          req.options.read_timeout = read_timeout if read_timeout
          req.body = body if body
        end
        raise_for_status!(resp)
        resp
      rescue Faraday::ConnectionFailed => e
        # nada foi enviado → retry seguro
        raise Evolution::Errors::Transient, e.message
      rescue Faraday::TimeoutError => e
        # connect-phase (nada enviado) → Transient ; read-phase (pode ter processado) → Unknown
        raise classify_timeout(e), e.message
      ensure
        ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        Rails.logger.info("[evolution] #{method.to_s.upcase} #{path} -> #{resp ? resp.status : 'ERR'} (#{ms}ms)")
      end

      # Mapeia toda resposta não-2xx para exatamente uma classe Evolution::Errors.
      # Contrato do envelope verificado (evolution-contract.md):
      #   { "status": <int>, "error": <string>, "response": { "message": <string | string[]> } }
      # `message` é String no 401 e Array no 404 — normalizar sempre com Array(...).join.
      def raise_for_status!(resp)
        return if resp.success?

        body = resp.body

        # Corpo 5xx não-JSON (página de erro HTML da Cloudflare, não conteúdo do
        # Evolution) → Transient genérico. NUNCA ecoar o HTML na mensagem.
        if resp.status >= 500 && !body.is_a?(Hash)
          raise Evolution::Errors::Transient, "#{resp.status} upstream 5xx (non-JSON body)"
        end

        raw = body.is_a?(Hash) ? body.dig("response", "message") : body
        msg = Array(raw).join(" ")
        case resp.status
        when 400, 401, 403, 404, 422
          raise Evolution::Errors::Permanent, "#{resp.status} #{msg}".strip
        when 408, 429, 500..599
          raise Evolution::Errors::Transient, "#{resp.status} #{msg}".strip
        else
          raise Evolution::Errors::Unknown, "#{resp.status} #{msg}".strip
        end
      end

      # Distingue timeout de conexão (connect-phase, nada foi enviado → Transient)
      # de timeout de leitura (read-phase, a request pode ter sido processada →
      # Unknown, nunca retry automático). Quando o Faraday não expõe a fase,
      # o default seguro é Unknown.
      def classify_timeout(error)
        wrapped = error.respond_to?(:wrapped_exception) ? error.wrapped_exception : nil
        case wrapped
        when Net::OpenTimeout
          Evolution::Errors::Transient
        when Net::ReadTimeout
          Evolution::Errors::Unknown
        else
          Evolution::Errors::Unknown
        end
      end
    end
  end
end

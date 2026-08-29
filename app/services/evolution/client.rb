# frozen_string_literal: true

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

      # GET /instance/fetchInstances — leitura rápida. Retorna o corpo (Array).
      def fetch_instances(api_key: Evolution.global_api_key)
        request(:get, "/instance/fetchInstances",
                api_key: api_key, read_timeout: Evolution::READ_TIMEOUT_FAST).body
      end

      # GET /instance/connectionState/{instance} — retorna a string crua
      # "open" / "connecting" / "close". Levantar NotConnected é papel do chamador
      # (fase 29); use assert_open! quando quiser transformar em erro.
      def connection_state(instance_name, api_key: Evolution.global_api_key)
        resp = request(:get, "/instance/connectionState/#{instance_name}",
                       api_key: api_key, read_timeout: Evolution::READ_TIMEOUT_FAST)
        resp.body.dig("instance", "state")
      end

      private

      def request(method, path, api_key:, body: nil, read_timeout: nil)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        resp = nil
        resp = connection.public_send(method, path) do |req|
          req.headers["apikey"] = api_key
          req.options.timeout = read_timeout if read_timeout
          req.body = body if body
        end
        raise_for_status!(resp)
        resp
      rescue Faraday::ConnectionFailed => e
        # nada foi enviado → retry seguro
        raise Evolution::Errors::Transient, e.message
      rescue Faraday::TimeoutError => e
        # handler mínimo — Task 2 distingue connect-phase (Transient) de read-phase (Unknown).
        # Default seguro: Unknown (a request pode ter sido processada).
        raise Evolution::Errors::Unknown, e.message
      ensure
        ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        Rails.logger.info("[evolution] #{method.to_s.upcase} #{path} -> #{resp ? resp.status : 'ERR'} (#{ms}ms)")
      end

      # Mapeamento mínimo (Task 1). Task 2 substitui pelo mapeamento completo
      # (corpo 5xx não-JSON da Cloudflare, 408/429, classify_timeout).
      def raise_for_status!(resp)
        return if resp.success?

        raw = resp.body.is_a?(Hash) ? resp.body.dig("response", "message") : resp.body
        msg = Array(raw).join(" ")
        case resp.status
        when 400, 401, 403, 404, 422
          raise Evolution::Errors::Permanent, "#{resp.status} #{msg}"
        when 408, 429, 500..599
          raise Evolution::Errors::Transient, "#{resp.status} #{msg}"
        else
          raise Evolution::Errors::Unknown, "#{resp.status} #{msg}"
        end
      end
    end
  end
end

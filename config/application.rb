require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CalendarioLivia
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Brasilia"
    config.active_record.default_timezone = :local
    config.i18n.default_locale = :'pt-BR'

    # CORS — insert before all other middleware so OPTIONS preflight
    # is handled before any authentication middleware (RESEARCH.md Pitfall 6)
    # Em produção, CORS_ORIGINS deve ser explicitamente provisionado; a ausência
    # da variável levanta KeyError (falha visível) em vez de aceitar qualquer origin.
    # Exceção: durante `assets:precompile` no build da imagem (SECRET_KEY_BASE_DUMMY=1,
    # sem env vars de runtime) — o middleware não roria de fato ali; um placeholder
    # inócuo evita o KeyError no build sem afrouxar a exigência em runtime.
    allowed_origins =
      if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
        ENV.fetch("CORS_ORIGINS")
      else
        ENV.fetch("CORS_ORIGINS", "http://localhost:3000")
      end

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins allowed_origins
        resource "/api/*",
          headers: :any,
          methods: [ :get, :post, :patch, :put, :delete, :options, :head ]
      end
    end

    config.middleware.use Rack::Attack

    # config.eager_load_paths << Rails.root.join("extras")
  end
end

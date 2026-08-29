# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
#
# :apikey / :hash — a chave global do Evolution viaja no header `apikey` e o token
# por instância é um `hash`; Evolution::Client (fase 25) já loga requests, então
# esses precisam ser filtrados agora. `:_key` não casa parcialmente `apikey` e
# `:token` não casa `hash`. O conjunto completo de filtros de segredo do Evolution
# (:api_key, :instance_token, :qrcode, :base64, :pairing_code) entra na INFRA-04
# (fase 26), antes do primeiro token por instância ser gravado.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :apikey, :hash
]

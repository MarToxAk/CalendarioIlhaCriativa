# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
#
# :apikey / :hash — a chave global do Evolution viaja no header `apikey` e o token
# por instância é um `hash`; Evolution::Client (fase 25) já loga requests, então
# esses precisam ser filtrados. `:_key` não casa parcialmente `apikey` e
# `:token` não casa `hash`, por isso a lista precisa dos símbolos extras, não de
# regex. INFRA-04 (fase 26) fecha aqui: :api_key, :instance_token, :qrcode,
# :base64, :pairing_code, :pairingCode cobrem create_instance/connect/webhook
# (QR base64, pairing code, apikey de instância) antes do primeiro token de
# whatsapp_instances ser gravado.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :apikey, :hash,
  :api_key, :instance_token, :qrcode, :base64, :pairing_code, :pairingCode
]

# frozen_string_literal: true

# Serve a documentacao da API de IA (docs/api-ia.md) como Markdown, para o proprio
# agente ler. Herda a autenticacao por ak_ key do controller base: a documentacao
# descreve operacoes reais e nao fica publica.
class Api::V1::Ai::DocsController < Api::V1::Ai::BaseController
  DOC_PATH = Rails.root.join("docs", "api-ia.md")

  def show
    render plain: DOC_PATH.read, content_type: "text/markdown; charset=utf-8"
  end
end

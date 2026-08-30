# Be sure to restart your server when you modify this file.

# Inflexoes irregulares para o dominio pt-BR. "Divulgacao" pluraliza para
# "divulgacaos" pela regra inglesa default do Rails, o que quebra o nome da
# tabela `divulgacoes`, os helpers de rota, `dom_id` e
# `form_with model: [@client, @divulgacao]`.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular "divulgacao", "divulgacoes"
  inflect.irregular "divulgacao_grupo", "divulgacao_grupos"
end

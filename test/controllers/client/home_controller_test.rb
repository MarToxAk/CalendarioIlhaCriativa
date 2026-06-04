require "test_helper"

class Client::HomeControllerTest < ActionDispatch::IntegrationTest
  def setup
    @client = Client.create!(
      name: "Livia Teste",
      password: "senha123",
      password_confirmation: "senha123"
    )
  end

  def sign_in_as_client(client, password: "senha123")
    post client_session_path(token: client.access_token), params: { password: password }
  end

  test "exibe grade mensal para mês corrente sem parâmetro month" do
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    assert_includes response.body, Date.today.day.to_s
  end

  test "exibe artes do mês na grade" do
    arte = Arte.create!(
      client: @client,
      scheduled_on: Date.today,
      platform: :instagram,
      media_type: :caption_only,
      external_url: "https://drive.google.com/file/exemplo"
    )
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    assert_includes response.body.downcase, "instagram"
  end

  test "navega para mês anterior via ?month=" do
    sign_in_as_client(@client)
    prev_month = (Date.today - 1.month).strftime("%Y-%m")
    get client_root_path(token: @client.access_token, month: prev_month)
    assert_response :success
  end

  test "parâmetro month inválido não causa erro 500" do
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token, month: "abc")
    assert_response :success
  end

  test "requer autenticação — sem sessão redireciona para login" do
    get client_root_path(token: @client.access_token)
    assert_redirected_to new_client_session_path(token: @client.access_token)
  end

  # CAL2-01: summary strip tests (rendered HTML, sem rails-controller-testing)
  test "summary strip não aparece quando não há artes no mês corrente" do
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    assert_no_match(/role="status"/, response.body)
  end

  test "summary strip aparece quando há artes no mês corrente" do
    Arte.create!(client: @client, scheduled_on: Date.today.beginning_of_month,
                 platform: :instagram, media_type: :caption_only,
                 external_url: "https://example.com/a")
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    assert_match(/role="status"/, response.body)
    assert_match(/aria-label="Resumo do mês"/, response.body)
  end

  test "summary strip exibe contagem total correta" do
    2.times do |i|
      Arte.create!(client: @client, scheduled_on: Date.today.beginning_of_month,
                   platform: :instagram, media_type: :caption_only,
                   external_url: "https://example.com/#{i}")
    end
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    assert_match(/2.*total/m, response.body)
  end

  test "summary strip conta apenas artes do mês corrente, excluindo outros meses" do
    this_month = Date.today.beginning_of_month
    other_month = (Date.today - 2.months).beginning_of_month
    Arte.create!(client: @client, scheduled_on: this_month, platform: :instagram,
                 media_type: :caption_only, external_url: "https://example.com/a")
    Arte.create!(client: @client, scheduled_on: other_month, platform: :instagram,
                 media_type: :caption_only, external_url: "https://example.com/b")
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    # Apenas 1 arte do mês corrente
    assert_match(/1.*total/m, response.body)
  end

  test "summary strip exibe chip aprovadas para artes approved" do
    Arte.create!(client: @client, scheduled_on: Date.today.beginning_of_month,
                 platform: :instagram, media_type: :caption_only,
                 external_url: "https://example.com/c", status: :approved)
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    assert_match(/1.*aprovadas/m, response.body)
  end

  test "summary strip conta status revised junto com pending (D-04)" do
    Arte.create!(client: @client, scheduled_on: Date.today.beginning_of_month,
                 platform: :instagram, media_type: :caption_only,
                 external_url: "https://example.com/e", status: :pending)
    Arte.create!(client: @client, scheduled_on: Date.today.beginning_of_month,
                 platform: :instagram, media_type: :caption_only,
                 external_url: "https://example.com/f", status: :revised)
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    assert_match(/2.*pendentes/m, response.body)
  end

  test "summary strip exibe chip pediu alteração para artes change_requested" do
    Arte.create!(client: @client, scheduled_on: Date.today.beginning_of_month,
                 platform: :instagram, media_type: :caption_only,
                 external_url: "https://example.com/g", status: :change_requested)
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token)
    assert_response :success
    assert_match(/1.*pediu alteração/m, response.body)
  end

  # FERI-02: feriados brasileiros no calendário do cliente
  test "exibe nome de feriado no calendário do cliente" do
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token, month: "2026-04")
    assert_response :success
    assert_includes response.body, "Tiradentes"
    assert_includes response.body, "Páscoa"
  end

  test "dias sem feriado não exibem texto de feriado (regressão FERI-02)" do
    sign_in_as_client(@client)
    get client_root_path(token: @client.access_token, month: "2026-04")
    assert_response :success
    assert_no_match(/brazilianholiday/i, response.body)
    assert_no_match(/undefined method/i, response.body)
  end
end

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
end

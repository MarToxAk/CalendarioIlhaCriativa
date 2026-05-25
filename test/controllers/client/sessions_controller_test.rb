require "test_helper"

class Client::SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @client = Client.create!(
      name: "Test",
      password: "senha123",
      password_confirmation: "senha123"
    )
  end

  test "GET /c/TOKEN/session/new retorna 200" do
    get new_client_session_path(token: @client.access_token)
    assert_response :success
  end

  test "POST com senha correta cria sessão e redireciona (AUTH-04)" do
    post client_session_path(token: @client.access_token), params: { password: "senha123" }
    assert_equal @client.id, session[:client_id]
    assert_equal @client.token_version, session[:client_token_version]
    assert_response :redirect
  end

  test "POST com senha errada retorna 422 com mensagem de erro (AUTH-04)" do
    post client_session_path(token: @client.access_token), params: { password: "errada" }
    assert_response :unprocessable_entity
    assert_includes response.body, "Senha incorreta"
  end

  test "rotação de token invalida sessão existente (AUTH-05)" do
    post client_session_path(token: @client.access_token), params: { password: "senha123" }
    assert_equal @client.id, session[:client_id]

    @client.regenerate_access_token
    @client.reload

    delete client_session_path(token: @client.access_token)
    assert_redirected_to new_client_session_path(token: @client.access_token)
    assert_nil session[:client_id]
  end

  test "DELETE /c/TOKEN/session limpa sessão e redireciona (AUTH-06)" do
    post client_session_path(token: @client.access_token), params: { password: "senha123" }
    assert_equal @client.id, session[:client_id]

    delete client_session_path(token: @client.access_token)
    assert_nil session[:client_id]
    assert_nil session[:client_token_version]
    assert_response :redirect
  end

  # ── clientes inativos (CLIE-03) ──────────────────────────────────────────────

  test "POST com senha correta mas cliente inativo retorna 403 com mensagem de bloqueio (CLIE-03)" do
    @client.update!(active: false)
    post client_session_path(token: @client.access_token), params: { password: "senha123" }
    assert_response :forbidden
    assert_includes response.body, "Acesso bloqueado"
  end

  test "GET portal de cliente inativo retorna 403 (load_client_from_token guard)" do
    @inactive_client = Client.create!(name: "Inativo", password: "x", active: false)
    get new_client_session_path(token: @inactive_client.access_token)
    assert_response :forbidden
    assert_includes response.body, "Acesso bloqueado"
  end
end

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = "SenhaSegura123!"

  setup do
    Rack::Attack.cache.store.clear
    User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    @user = User.find_by!(email_address: ADMIN_EMAIL)
  end

  # Test 1: POST /session com credenciais corretas → redirect para /admin
  test "login com credenciais corretas redireciona para admin dashboard" do
    post session_path, params: { email_address: ADMIN_EMAIL, password: ADMIN_PASSWORD }
    assert_redirected_to admin_root_path
  end

  # Test 2: POST /session com senha errada → redirect com mensagem de erro
  test "login com senha errada retorna erro" do
    post session_path, params: { email_address: ADMIN_EMAIL, password: "senhaerrada" }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "incorretos", response.body
  end

  # Test 3: DELETE /session → Session.count diminui e redireciona
  test "logout destroi a sessao e redireciona" do
    sign_in_as(@user)
    initial_count = Session.count
    delete session_path
    assert_redirected_to new_session_path
    assert_equal initial_count - 1, Session.count
  end

  # Test 4: GET /admin/dashboard sem autenticacao → redirect 302
  test "dashboard sem autenticacao redireciona para login" do
    get admin_root_path
    assert_response :redirect
    assert_redirected_to new_session_path
  end

  # Test 5: GET /admin/dashboard com sessao valida → 200
  test "dashboard com sessao valida retorna 200" do
    sign_in_as(@user)
    get admin_root_path
    assert_response :success
  end
end

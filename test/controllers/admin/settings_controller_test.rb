require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)

    @user = User.create!(
      email_address: "admin_settings@test.com",
      password: "senha_original",
      password_confirmation: "senha_original",
      agency_name: "Agência Teste"
    )
    post session_path, params: { email_address: @user.email_address, password: "senha_original" }
  end

  teardown do
    @user.destroy
  end

  # ───── show ─────

  test "GET settings — autenticado: 200" do
    # View created in Wave 3 — will pass after 15-03-PLAN.md executes
    skip "View not yet created (Wave 3)"
  end

  test "GET settings — não autenticado: redireciona para login" do
    delete session_path
    get admin_settings_path
    assert_redirected_to new_session_path
  end

  # ───── update_password ─────

  test "PATCH update_password — senha atual correta e nova válida: redireciona com notice" do
    patch update_password_admin_settings_path, params: {
      password_current: "senha_original",
      password: "nova_senha_123",
      password_confirmation: "nova_senha_123"
    }
    assert_redirected_to admin_settings_path
    assert_equal "Senha alterada com sucesso.", flash[:notice]
    assert @user.reload.authenticate("nova_senha_123")
  end

  test "PATCH update_password — senha atual errada: redireciona com alert, senha inalterada" do
    patch update_password_admin_settings_path, params: {
      password_current: "errada",
      password: "nova_senha_123",
      password_confirmation: "nova_senha_123"
    }
    assert_redirected_to admin_settings_path
    assert_equal "Senha atual incorreta.", flash[:alert]
    assert @user.reload.authenticate("senha_original")
  end

  test "PATCH update_password — nova senha em branco: redireciona com alert" do
    patch update_password_admin_settings_path, params: {
      password_current: "senha_original",
      password: "",
      password_confirmation: ""
    }
    assert_redirected_to admin_settings_path
    assert_match /em branco/, flash[:alert]
  end

  test "PATCH update_password — confirmação não coincide: redireciona com alert" do
    patch update_password_admin_settings_path, params: {
      password_current: "senha_original",
      password: "nova_senha_123",
      password_confirmation: "diferente"
    }
    assert_redirected_to admin_settings_path
    assert_match /não coincidem/, flash[:alert]
  end

  # ───── update_agency ─────

  test "PATCH update_agency — nome válido: atualiza e redireciona com notice" do
    patch update_agency_admin_settings_path, params: { agency_name: "Nova Agência" }
    assert_redirected_to admin_settings_path
    assert_equal "Nome da agência atualizado.", flash[:notice]
    assert_equal "Nova Agência", @user.reload.agency_name
  end

  test "PATCH update_agency — nome em branco: redireciona com alert" do
    patch update_agency_admin_settings_path, params: { agency_name: "" }
    assert_redirected_to admin_settings_path
    assert flash[:alert].present?
    assert_equal "Agência Teste", @user.reload.agency_name
  end
end

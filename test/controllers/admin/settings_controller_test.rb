require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email_address: "admin@test.com",
      password: "senha123",
      password_confirmation: "senha123",
      agency_name: "Agência Teste"
    )
    post session_path, params: { email_address: @user.email_address, password: "senha123" }
  end

  teardown do
    @user.destroy
  end

  # Wave 2 testes serão adicionados aqui
  test "placeholder" do
    assert true
  end
end

require "test_helper"

class Admin::CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "admin@example.com", password: "password", password_confirmation: "password")
    sign_in_as(@user)
    @client = Client.create!(name: "Test Client", password: "senha123", password_confirmation: "senha123")
    @arte = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :pending,
      title: "Arte Teste",
      caption: "Legenda",
      approval_deadline: Date.current + 5,
      external_url: "https://drive.google.com/file/exemplo"
    )
  end

  test "GET /admin/calendar retorna 200 quando autenticado" do
    get admin_calendar_index_url
    assert_response :success
  end

  test "GET /admin/calendar redireciona quando nao autenticado" do
    delete session_path
    get admin_calendar_index_url
    assert_response :redirect
  end

  test "GET /admin/calendar com parametro month valido retorna 200" do
    get admin_calendar_index_url, params: { month: "2026-06" }
    assert_response :success
  end

  test "GET /admin/calendar com parametro month invalido retorna 200 sem 500" do
    get admin_calendar_index_url, params: { month: "invalid" }
    assert_response :success
  end
end

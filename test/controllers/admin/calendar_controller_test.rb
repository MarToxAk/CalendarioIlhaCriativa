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

  # Testes adicionados no plano 14-03

  test "test_returns_200_when_authenticated" do
    get admin_calendar_index_url
    assert_response :success
  end

  test "test_redirects_when_unauthenticated" do
    delete session_path
    get admin_calendar_index_url
    assert_response :redirect
  end

  test "test_displays_client_name" do
    get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
    assert_response :success
    assert_includes response.body, @client.name
  end

  test "test_navigates_to_specific_month" do
    get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
    assert_response :success
  end

  test "test_invalid_month_param_does_not_crash" do
    get admin_calendar_index_url, params: { month: "invalid" }
    assert_response :success
  end

  test "test_chip_contains_client_initials" do
    get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
    assert_response :success
    initials = @client.name.split.map(&:first).first(2).join.upcase
    assert_includes response.body, initials
  end

  test "test_chip_links_to_arte" do
    get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
    assert_response :success
    assert_includes response.body, admin_arte_path(@arte)
  end

  test "test_overflow_shows_plus_n" do
    4.times do |i|
      Arte.create!(
        client: @client,
        scheduled_on: @arte.scheduled_on,
        platform: :instagram,
        media_type: :image,
        status: :pending,
        caption: "cap",
        approval_deadline: Date.current + 5,
        external_url: "https://drive.google.com/file/extra#{i}"
      )
    end
    get admin_calendar_index_url, params: { month: @arte.scheduled_on.strftime("%Y-%m") }
    assert_response :success
    assert_includes response.body, "+2"
  end
end

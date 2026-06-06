require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
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
    Rack::Attack.cache.store.clear if defined?(Rack::Attack)
  end

  test "should get index" do
    get admin_root_url
    assert_response :success
  end

  test "filter by client_id" do
    get admin_root_url, params: { client_id: @client.id }
    assert_response :success
  end

  test "filter by status" do
    get admin_root_url, params: { status: "pending" }
    assert_response :success
  end

  test "filter by invalid status is ignored and returns all artes" do
    get admin_root_url, params: { status: "nonexistent_status" }
    assert_response :success
    assert_includes response.body, @arte.title
  end

  # Testes de infraestrutura real-time (Phase 17 Plan 03)

  test "renders admin toast region in layout" do
    get admin_root_url
    assert_response :success
    assert_select "div#admin-toast-region"
  end

  test "renders turbo stream from for admin notifications in layout" do
    get admin_root_url
    assert_response :success
    assert_select "turbo-cable-stream-source"
  end

  # Testes de badge no sidebar (Phase 17 Plan 03)

  test "sidebar badge present when change_requested artes exist" do
    @arte.update!(status: :change_requested)
    get admin_root_url
    assert_response :success
    assert_select "span#sidebar-badge"
  end

  test "sidebar badge absent when no change_requested artes" do
    @arte.update!(status: :pending)
    get admin_root_url
    assert_response :success
    assert_select "span#sidebar-badge.hidden"
  end
end

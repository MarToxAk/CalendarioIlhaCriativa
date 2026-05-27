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
end

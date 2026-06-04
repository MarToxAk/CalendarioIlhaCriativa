require "test_helper"

class Admin::ApprovalsControllerTest < ActionDispatch::IntegrationTest
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
    @approval_response = ApprovalResponse.create!(arte: @arte, decision: :approved)
  end

  test "test_should_get_index" do
    get admin_approvals_url
    assert_response :success
  end

  test "test_redirects_when_unauthenticated" do
    delete session_path
    get admin_approvals_url
    assert_response :redirect
  end

  test "test_displays_approval_data" do
    get admin_approvals_url
    assert_response :success
    assert_includes response.body, @client.name
    assert_includes response.body, @arte.title
  end

  test "test_filter_by_client_id" do
    get admin_approvals_url, params: { client_id: @client.id }
    assert_response :success
    assert_includes response.body, @client.name
  end

  test "test_filter_by_decision_approved" do
    get admin_approvals_url, params: { decision: "approved" }
    assert_response :success
    assert_includes response.body, @arte.title
  end

  test "test_filter_by_decision_change_requested" do
    get admin_approvals_url, params: { decision: "change_requested" }
    assert_response :success
  end

  test "test_filter_by_invalid_decision" do
    get admin_approvals_url, params: { decision: "nonexistent" }
    assert_response :success
    assert_includes response.body, @arte.title
  end

  test "test_link_to_arte_present" do
    get admin_approvals_url
    assert_response :success
    assert_includes response.body, admin_arte_path(@arte)
  end
end

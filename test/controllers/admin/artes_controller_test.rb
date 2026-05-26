require "test_helper"

class Admin::ArtesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "admin@example.com", password: "password", password_confirmation: "password")
    sign_in_as(@user)
    @client = Client.create!(name: "Test", password: "senha123", password_confirmation: "senha123")
    @arte = Arte.create!(client: @client, scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :pending, title: "Arte Teste", caption: "Legenda", approval_deadline: Date.current + 5, external_url: "https://drive.google.com/file/exemplo")
  end

  test "should get index" do
    get admin_artes_url
    assert_response :success
  end

  test "should show arte" do
    get admin_arte_url(@arte)
    assert_response :success
  end

  test "should get new" do
    get new_admin_arte_url
    assert_response :success
  end

  test "should create arte" do
    assert_difference("Arte.count") do
      post admin_artes_url, params: { arte: { client_id: @client.id, scheduled_on: Date.current, platform: :instagram, media_type: :image, status: :pending, title: "Nova Arte", caption: "Teste", approval_deadline: Date.current + 5, external_url: "https://drive.google.com/file/novo" } }
    end
    assert_redirected_to admin_arte_url(Arte.last)
  end

  test "should not edit non-pending arte" do
    @arte.update!(status: :approved)
    get edit_admin_arte_url(@arte)
    assert_redirected_to admin_arte_url(@arte)
    follow_redirect!
    assert_match /Edição bloqueada/, response.body
  end

  test "should destroy pending arte" do
    assert_difference("Arte.count", -1) do
      delete admin_arte_url(@arte)
    end
    assert_redirected_to admin_artes_url
  end

  test "should not destroy non-pending arte" do
    @arte.update!(status: :approved)
    assert_no_difference("Arte.count") do
      delete admin_arte_url(@arte)
    end
    assert_redirected_to admin_arte_url(@arte)
    follow_redirect!
    assert_match /Exclusão bloqueada/, response.body
  end

  test "mark_revised muda status para revised quando change_requested" do
    @arte.update!(status: :change_requested)
    patch mark_revised_admin_arte_url(@arte)
    assert_redirected_to admin_arte_url(@arte)
    assert @arte.reload.revised?
  end

  test "mark_revised rejeita arte nao change_requested" do
    # @arte está com status :pending
    patch mark_revised_admin_arte_url(@arte)
    assert_redirected_to admin_arte_url(@arte)
    follow_redirect!
    assert_match /Ação inválida/, response.body
  end

  test "ciclo completo APRO-03: revised aceita nova aprovacao do cliente" do
    # Avança arte para change_requested via ApprovalResponse
    @arte.approval_responses.create!(decision: :change_requested)
    assert @arte.reload.change_requested?

    # Admin marca como revisada
    patch mark_revised_admin_arte_url(@arte)
    assert_redirected_to admin_arte_url(@arte)
    assert @arte.reload.revised?

    # Cliente aprova a arte revisada (validator aceita revised?)
    response = @arte.approval_responses.build(decision: :approved)
    assert response.valid?, "ApprovalResponse deve ser válida para arte com status revised"
    response.save!
    assert @arte.reload.approved?, "Arte deve ficar approved após aprovação pelo cliente"
  end
end

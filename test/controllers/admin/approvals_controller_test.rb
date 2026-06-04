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

  # Testes adicionados no plano 13-02
end

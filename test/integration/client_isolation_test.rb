require "test_helper"

class ClientIsolationTest < ActionDispatch::IntegrationTest
  def setup
    @client_a = Client.create!(name: "Cliente A", password: "senhaA", password_confirmation: "senhaA")
    @client_b = Client.create!(name: "Cliente B", password: "senhaB", password_confirmation: "senhaB")
    @arte_b = Arte.create!(
      client: @client_b,
      scheduled_on: Date.current,
      external_url: "https://drive.google.com/file/exemplo"
    )
  end

  test "cliente A autenticado não acessa rota de cliente B (isolamento cross-client)" do
    post client_session_path(token: @client_a.access_token), params: { password: "senhaA" }
    assert_equal @client_a.id, session[:client_id]

    get client_root_path(token: @client_b.access_token)
    assert_response :redirect
    assert_nil session[:client_id]
  end

  test "escopo de artes por cliente impede acesso cross-client (isolamento model)" do
    assert_raises(ActiveRecord::RecordNotFound) do
      @client_a.artes.find(@arte_b.id)
    end
  end
end

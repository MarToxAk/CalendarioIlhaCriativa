require "test_helper"

class Client::ArtesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @client_a = Client.create!(
      name: "Cliente A",
      password: "senha123",
      password_confirmation: "senha123"
    )
    @client_b = Client.create!(
      name: "Cliente B",
      password: "senha456",
      password_confirmation: "senha456"
    )
    @arte_a = Arte.create!(
      client: @client_a,
      scheduled_on: Date.today,
      platform: :instagram,
      media_type: :caption_only,
      external_url: "https://drive.google.com/file/arte-a"
    )
    @arte_b = Arte.create!(
      client: @client_b,
      scheduled_on: Date.today,
      platform: :facebook,
      media_type: :caption_only,
      external_url: "https://drive.google.com/file/arte-b"
    )
  end

  def sign_in_as_client(client, password: "senha123")
    post client_session_path(token: client.access_token), params: { password: password }
  end

  test "acessa arte do proprio cliente" do
    sign_in_as_client(@client_a)
    get client_arte_path(token: @client_a.access_token, id: @arte_a.id)
    assert_response :success
  end

  test "nao acessa arte de outro cliente" do
    sign_in_as_client(@client_a)
    get client_arte_path(token: @client_a.access_token, id: @arte_b.id)
    assert_redirected_to client_root_path(token: @client_a.access_token)
  end

  test "sem autenticacao redireciona para login" do
    get client_arte_path(token: @client_a.access_token, id: @arte_a.id)
    assert_redirected_to new_client_session_path(token: @client_a.access_token)
  end

  test "arte inexistente redireciona para calendario" do
    sign_in_as_client(@client_a)
    get client_arte_path(token: @client_a.access_token, id: 999999)
    assert_redirected_to client_root_path(token: @client_a.access_token)
  end
end

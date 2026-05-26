require "test_helper"

class Client::ResponsesControllerTest < ActionDispatch::IntegrationTest
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

  # Test 1 (APRO-01): POST com decision: approved → arte aprovada, flash "Arte aprovada!"
  test "POST approved aprova a arte e redireciona com flash" do
    sign_in_as_client(@client_a)
    assert_difference "ApprovalResponse.count", 1 do
      post client_arte_responses_path(token: @client_a.access_token, arte_id: @arte_a.id),
           params: { approval_response: { decision: "approved" } }
    end
    assert_redirected_to client_arte_path(token: @client_a.access_token, id: @arte_a.id)
    assert_equal "Arte aprovada!", flash[:notice]
    assert @arte_a.reload.approved?
  end

  # Test 2 (APRO-02): POST com decision: change_requested e comment salvo
  test "POST change_requested com comentario salva resposta e redireciona com flash" do
    sign_in_as_client(@client_a)
    assert_difference "ApprovalResponse.count", 1 do
      post client_arte_responses_path(token: @client_a.access_token, arte_id: @arte_a.id),
           params: { approval_response: { decision: "change_requested", comment: "Mudar cor" } }
    end
    assert_redirected_to client_arte_path(token: @client_a.access_token, id: @arte_a.id)
    assert_equal "Pedido de alteração enviado.", flash[:notice]
    assert @arte_a.reload.change_requested?
    assert_equal "Mudar cor", ApprovalResponse.last.comment
  end

  # Test 3 (APRO-02 comentário opcional): POST change_requested sem comment → válido
  test "POST change_requested sem comentario e valido" do
    sign_in_as_client(@client_a)
    assert_difference "ApprovalResponse.count", 1 do
      post client_arte_responses_path(token: @client_a.access_token, arte_id: @arte_a.id),
           params: { approval_response: { decision: "change_requested" } }
    end
    assert_redirected_to client_arte_path(token: @client_a.access_token, id: @arte_a.id)
    assert @arte_a.reload.change_requested?
    assert_nil ApprovalResponse.last.comment
  end

  # Test 4 (APRO-05 duplo-envio): POST para arte já approved → redirect com alert
  test "POST para arte ja aprovada e rejeitado pelo validator" do
    @arte_a.approved!
    sign_in_as_client(@client_a)
    assert_no_difference "ApprovalResponse.count" do
      post client_arte_responses_path(token: @client_a.access_token, arte_id: @arte_a.id),
           params: { approval_response: { decision: "approved" } }
    end
    assert_redirected_to client_arte_path(token: @client_a.access_token, id: @arte_a.id)
    assert flash[:alert].present?
    assert @arte_a.reload.approved?
  end

  # Test 5 (IDOR): POST com arte_id de @client_b enquanto autenticado como @client_a
  test "POST com arte de outro cliente redireciona para calendario sem criar resposta" do
    sign_in_as_client(@client_a)
    assert_no_difference "ApprovalResponse.count" do
      post client_arte_responses_path(token: @client_a.access_token, arte_id: @arte_b.id),
           params: { approval_response: { decision: "approved" } }
    end
    assert_redirected_to client_root_path(token: @client_a.access_token)
  end

  # Test 6 (sem auth): POST sem sessão → redirect para login
  test "POST sem autenticacao redireciona para login" do
    post client_arte_responses_path(token: @client_a.access_token, arte_id: @arte_a.id),
         params: { approval_response: { decision: "approved" } }
    assert_redirected_to new_client_session_path(token: @client_a.access_token)
  end
end

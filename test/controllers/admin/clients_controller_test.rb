require "test_helper"

class AdminClientsControllerTest < ActionDispatch::IntegrationTest
  ADMIN_EMAIL    = "admin@ilhacriativa.com.br"
  ADMIN_PASSWORD = ENV.fetch("ADMIN_PASSWORD", "SenhaSegura123!")

  setup do
    @admin = User.find_or_create_by!(email_address: ADMIN_EMAIL) do |u|
      u.password = ADMIN_PASSWORD
      u.password_confirmation = ADMIN_PASSWORD
    end
    sign_in_as(@admin)

    @client = Client.create!(
      name: "Test Client",
      password: "senha1234",
      password_plain: "senha1234"
    )
  end

  # ── create ──────────────────────────────────────────────────────────────────

  test "create com dados válidos redireciona para show com notice" do
    assert_difference "Client.count", 1 do
      post admin_clients_path, params: {
        client: { name: "Loja da Maria", password: "abcd1234" }
      }
    end
    novo_cliente = Client.last
    assert_redirected_to admin_client_path(novo_cliente)
    assert_equal "Cliente cadastrado com sucesso.", flash[:notice]
    assert_equal "abcd1234", novo_cliente.password_plain
  end

  test "create com nome vazio renderiza new com status 422" do
    assert_no_difference "Client.count" do
      post admin_clients_path, params: {
        client: { name: "", password: "abcd1234" }
      }
    end
    assert_response :unprocessable_entity
    assert_select "span[role='alert']"
  end

  # ── update ──────────────────────────────────────────────────────────────────

  test "update com senha em branco mantém senha original (D-10)" do
    senha_original = @client.password_plain
    patch admin_client_path(@client), params: {
      client: { name: "Nome Novo", password: "", password_plain: "" }
    }
    assert_redirected_to admin_client_path(@client)
    @client.reload
    assert_equal senha_original, @client.password_plain
    assert_equal "Nome Novo", @client.name
  end

  test "update com dados inválidos renderiza edit com status 422" do
    patch admin_client_path(@client), params: {
      client: { name: "" }
    }
    assert_response :unprocessable_entity
  end
end

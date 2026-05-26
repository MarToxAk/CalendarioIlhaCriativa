require "test_helper"

class ClientTest < ActiveSupport::TestCase
  def setup
    @client = Client.create!(
      name: "Cliente Teste",
      password: "senha123",
      password_confirmation: "senha123"
    )
  end

  test "token gerado automaticamente tem 24 chars" do
    assert_equal 24, @client.access_token.length
  end

  test "dois clientes têm tokens diferentes" do
    outro = Client.create!(name: "Outro", password: "abc123", password_confirmation: "abc123")
    assert_not_equal @client.access_token, outro.access_token
  end

  test "authenticate com senha correta retorna o client" do
    assert_equal @client, @client.authenticate("senha123")
  end

  test "authenticate com senha errada retorna false" do
    assert_equal false, @client.authenticate("errada")
  end

  test "regenerate_access_token muda o token" do
    token_antigo = @client.access_token
    @client.regenerate_access_token
    assert_not_equal token_antigo, @client.access_token
  end

  test "client sem name é inválido" do
    client = Client.new(password: "senha123", password_confirmation: "senha123")
    assert_not client.valid?
    assert_includes client.errors[:name], "não pode ficar em branco"
  end

  test "token_version retorna primeiros 8 chars do access_token" do
    assert_equal @client.access_token.first(8), @client.token_version
  end
end

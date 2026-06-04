require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  def setup
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    @client = Client.create!(
      name: "Throttle Test",
      password: "senha123",
      password_confirmation: "senha123"
    )
  end

  test "5 primeiras tentativas não retornam 429" do
    5.times do
      post "/c/#{@client.access_token}/session", params: { password: "errada" }
      assert_not_equal 429, response.status
    end
  end

  test "6ª tentativa retorna 429" do
    6.times { post "/c/#{@client.access_token}/session", params: { password: "errada" } }
    assert_equal 429, response.status
  end

  test "resposta 429 contém 'Muitas tentativas'" do
    6.times { post "/c/#{@client.access_token}/session", params: { password: "errada" } }
    assert_includes response.body, "Muitas tentativas"
  end

  test "token diferente não é bloqueado quando outro token está bloqueado" do
    outro = Client.create!(name: "Outro", password: "abc123", password_confirmation: "abc123")
    6.times { post "/c/#{@client.access_token}/session", params: { password: "errada" } }
    post "/c/#{outro.access_token}/session", params: { password: "errada" }
    assert_not_equal 429, response.status
  end

  test "admin login bloqueado na 6ª tentativa" do
    6.times { post "/session", params: { email_address: "x@x.com", password: "errada" } }
    assert_equal 429, response.status
  end
end

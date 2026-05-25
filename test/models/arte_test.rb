require "test_helper"

class ArteTest < ActiveSupport::TestCase
  def setup
    @client = Client.create!(
      name: "Test",
      password: "senha123",
      password_confirmation: "senha123"
    )
    @arte_valida = Arte.new(
      client: @client,
      scheduled_on: Date.current,
      external_url: "https://drive.google.com/file/exemplo"
    )
  end

  test "arte sem scheduled_on é inválida" do
    arte = Arte.new(client: @client, external_url: "https://exemplo.com")
    assert_not arte.valid?
    assert_includes arte.errors[:scheduled_on], "can't be blank"
  end

  test "platform default é instagram" do
    assert_equal "instagram", Arte.new.platform
  end

  test "status default é pending" do
    assert_equal "pending", Arte.new.status
  end

  test "arte sem media_file e sem external_url é inválida" do
    arte = Arte.new(client: @client, scheduled_on: Date.current)
    assert_not arte.valid?
    assert_includes arte.errors[:base], "Precisa de arquivo ou link externo"
  end

  test "arte com external_url válido é válida" do
    assert @arte_valida.valid?, @arte_valida.errors.full_messages.inspect
  end
end

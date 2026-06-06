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
    assert_includes arte.errors[:scheduled_on], "não pode ficar em branco"
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

  test "revised! dispara broadcast para ClientCalendarChannel e AdminNotificationsChannel" do
    # broadcasts_revised_to_all faz User.order(:id).first e retorna cedo se nil.
    # Explicitamos a dependência para que a mensagem de falha seja clara caso
    # os fixtures de User sejam removidos (WR-02).
    assert User.exists?, "Este teste requer ao menos um User (fixture users.yml)"

    arte = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :change_requested,
      external_url: "https://drive.google.com/file/test"
    )

    client_calls = []
    admin_calls  = []

    ClientCalendarChannel.stub(:broadcast_to, ->(c, content) { client_calls << content }) do
      AdminNotificationsChannel.stub(:broadcast_to, ->(u, content) { admin_calls << content }) do
        arte.revised!
      end
    end

    assert_equal 1, client_calls.length
    assert_equal 1, admin_calls.length
    assert_equal 2, client_calls.first.scan(/<turbo-stream/).count,
                 "Cliente deve receber 2 turbo streams: chip e toast (summary removido do broadcast — CR-01)"
    assert_equal 1, admin_calls.first.scan(/<turbo-stream/).count,
                 "Admin deve receber 1 turbo stream: badge decremento"
  end

  test "revised! nao dispara broadcast quando update nao muda status para revised" do
    arte = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :pending,
      external_url: "https://drive.google.com/file/test2"
    )

    client_calls = []

    ClientCalendarChannel.stub(:broadcast_to, ->(c, content) { client_calls << content }) do
      arte.update!(title: "Novo titulo")
    end

    assert_empty client_calls
  end

  test "revised! nao dispara broadcast quando status muda mas nao para revised" do
    arte = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :change_requested,
      external_url: "https://drive.google.com/file/test3"
    )

    client_calls = []

    ClientCalendarChannel.stub(:broadcast_to, ->(c, content) { client_calls << content }) do
      arte.approved!
    end

    assert_empty client_calls
  end
end

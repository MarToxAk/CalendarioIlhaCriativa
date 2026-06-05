require "test_helper"

class ApprovalResponseTest < ActiveSupport::TestCase
  def setup
    @client = Client.create!(
      name: "Test Client",
      password: "senha123",
      password_confirmation: "senha123"
    )
    @arte_pending = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :pending,
      external_url: "https://drive.google.com/file/exemplo"
    )
  end

  # Test 1: Múltiplas ApprovalResponses — segunda deve falhar apenas pelo validator,
  # não por unique violation
  test "segunda approval response falha por validator nao por unique violation" do
    ApprovalResponse.create!(arte: @arte_pending, decision: :approved)
    # Após approved!, @arte_pending agora está com status :approved
    @arte_pending.reload
    ar2 = ApprovalResponse.new(arte: @arte_pending, decision: :change_requested)
    assert_not ar2.valid?
    assert_includes ar2.errors[:arte], "não está em estado aprovável"
    # Garantir que o erro NÃO é de violação de índice único
    assert_no_match /unique|duplicate/i, ar2.errors.full_messages.join(" ")
  end

  # Test 2: Arte com status revised pode ter nova ApprovalResponse
  test "approval response valida para arte com status revised" do
    @arte_pending.revised!
    ar = ApprovalResponse.new(arte: @arte_pending, decision: :approved)
    assert ar.valid?, ar.errors.full_messages.inspect
  end

  # Test 3: Arte.approval_responses (has_many) funciona sem NoMethodError
  test "arte retorna collection proxy via has_many approval_responses" do
    assert_respond_to @arte_pending, :approval_responses
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @arte_pending.approval_responses
  end

  # Test 4: Arte revised — ApprovalResponse.new.valid? deve ser true
  test "approval response valida quando arte revised" do
    arte_revised = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :revised,
      external_url: "https://drive.google.com/file/revised"
    )
    ar = ApprovalResponse.new(arte: arte_revised, decision: :approved)
    assert ar.valid?, ar.errors.full_messages.inspect
  end

  # Test 5: Arte com status approved — ApprovalResponse.new.valid? deve ser false
  test "approval response invalida quando arte approved" do
    @arte_pending.approved!
    arte_approved = @arte_pending.reload
    ar = ApprovalResponse.new(arte: arte_approved, decision: :approved)
    assert_not ar.valid?
    assert_includes ar.errors[:arte], "não está em estado aprovável"
  end

  # ===========================================================================
  # Fase 18 — Testes para broadcasts_to_admin
  # Atualizados no Plan 03: stub posicional (user, content) + 4 streams em ambos
  # os casos (CR-02 — badge sempre broadcast).
  # ===========================================================================

  # Test A: broadcasts_to_admin deve ser método privado no model ApprovalResponse
  test "broadcasts_to_admin eh metodo privado definido no model" do
    ar = ApprovalResponse.new(arte: @arte_pending, decision: :change_requested)
    assert ar.respond_to?(:broadcasts_to_admin, true),
           "ApprovalResponse deve ter método privado broadcasts_to_admin"
  end

  # Test B: after_create_commit deve registrar :broadcasts_to_admin como callback
  test "after_create_commit registra broadcasts_to_admin" do
    assert_includes ApprovalResponse._commit_callbacks.map(&:filter), :broadcasts_to_admin,
                    "after_create_commit deve registrar :broadcasts_to_admin"
  end

  # Test C: AdminNotificationsChannel.broadcast_to é chamado exatamente 1x para change_requested
  test "change_requested cria approval e chama broadcast_to uma vez" do
    @broadcast_calls = []
    stub_fn = ->(user, content) { @broadcast_calls << { user: user, content: content } }
    AdminNotificationsChannel.stub(:broadcast_to, stub_fn) do
      ApprovalResponse.create!(arte: @arte_pending, decision: :change_requested)
    end
    assert_equal 1, @broadcast_calls.length,
                 "AdminNotificationsChannel.broadcast_to deve ser chamado exatamente 1 vez para change_requested"
  end

  # Test D: AdminNotificationsChannel.broadcast_to é chamado exatamente 1x para approved
  test "approved cria approval e chama broadcast_to uma vez" do
    arte_revised = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :revised,
      external_url: "https://drive.google.com/file/revised_for_approved"
    )
    @broadcast_calls = []
    stub_fn = ->(user, content) { @broadcast_calls << { user: user, content: content } }
    AdminNotificationsChannel.stub(:broadcast_to, stub_fn) do
      ApprovalResponse.create!(arte: arte_revised, decision: :approved)
    end
    assert_equal 1, @broadcast_calls.length,
                 "AdminNotificationsChannel.broadcast_to deve ser chamado exatamente 1 vez para approved"
  end

  # Test E (ATUALIZADO per CR-02): change_requested deve gerar 4 turbo-stream tags no content string
  test "change_requested broadcast gera 4 turbo streams" do
    @broadcast_calls = []
    stub_fn = ->(user, content) { @broadcast_calls << { user: user, content: content } }
    AdminNotificationsChannel.stub(:broadcast_to, stub_fn) do
      ApprovalResponse.create!(arte: @arte_pending, decision: :change_requested)
    end
    content = @broadcast_calls.first[:content]
    assert_equal 4, content.scan(/<turbo-stream/).count,
                 "change_requested deve gerar 4 turbo-stream tags: toast, badge, dashboard row e approvals prepend"
  end

  # Test F (ATUALIZADO per CR-02): approved também deve gerar 4 turbo-stream tags (badge sempre — CR-02)
  test "approved broadcast gera 4 turbo streams com badge" do
    arte_revised = Arte.create!(
      client: @client,
      scheduled_on: Date.current,
      platform: :instagram,
      media_type: :image,
      status: :revised,
      external_url: "https://drive.google.com/file/revised_for_streams"
    )
    @broadcast_calls = []
    stub_fn = ->(user, content) { @broadcast_calls << { user: user, content: content } }
    AdminNotificationsChannel.stub(:broadcast_to, stub_fn) do
      ApprovalResponse.create!(arte: arte_revised, decision: :approved)
    end
    content = @broadcast_calls.first[:content]
    assert_equal 4, content.scan(/<turbo-stream/).count,
                 "approved deve gerar 4 turbo-stream tags: toast, badge (sempre — CR-02), dashboard row e approvals prepend"
  end

  # Test G: broadcasts_to_admin não deve disparar N+1 para arte.client
  test "broadcasts_to_admin nao dispara N+1 para arte.client" do
    queries = []
    subscriber = ->(name, started, finished, unique_id, payload) { queries << payload[:sql].to_s }
    @broadcast_calls = []
    stub_fn = ->(user, content) { @broadcast_calls << { user: user, content: content } }
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      AdminNotificationsChannel.stub(:broadcast_to, stub_fn) do
        ApprovalResponse.create!(arte: @arte_pending, decision: :change_requested)
      end
    end
    arte_queries = queries.grep(/SELECT.*artes/i)
    assert(
      arte_queries.any? { |q| q.include?("JOIN") || q.include?("IN") },
      "Arte deve ser carregada com includes(:client) via JOIN/IN — não via N+1 queries separadas"
    )
  end
end

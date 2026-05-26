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
end

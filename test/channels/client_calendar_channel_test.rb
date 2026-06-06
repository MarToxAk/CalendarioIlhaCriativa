require "test_helper"

class ClientCalendarChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for current client" do
    stub_connection(current_client: clients(:one))
    subscribe
    assert subscription.confirmed?
    assert_has_stream_for clients(:one)
  end

  test "rejects subscription without current client" do
    stub_connection(current_user: nil, current_client: nil)
    subscribe
    assert subscription.rejected?
  end
end

require "test_helper"

class AdminNotificationsChannelTest < ActionCable::Channel::TestCase
  test "subscribes and streams for current user" do
    stub_connection(current_user: users(:one))
    subscribe
    assert subscription.confirmed?
    assert_has_stream_for users(:one)
  end

  test "rejects subscription without current user" do
    stub_connection(current_user: nil, current_client: nil)
    subscribe
    assert subscription.rejected?
  end
end

require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  setup do
    @user = users(:one)
    @session = @user.sessions.create!
  end

  test "connects admin via session cookie" do
    cookies.signed[:session_id] = @session.id
    connect
    assert_equal @user, connection.current_user
    assert_nil connection.current_client
  end

  test "connects client via token" do
    connect params: { token: clients(:one).access_token }
    assert_equal clients(:one), connection.current_client
    assert_nil connection.current_user
  end

  test "rejects connection without credentials" do
    assert_reject_connection { connect }
  end

  test "rejects inactive client" do
    assert_reject_connection { connect params: { token: clients(:inactive).access_token } }
  end
end

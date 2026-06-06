class ClientCalendarChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_client
    stream_for current_client
  end
end

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_client

    def connect
      set_current_user || set_current_client || reject_unauthorized_connection
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end

      def set_current_client
        token = request.params[:token]
        return nil if token.blank?
        if client = Client.find_by(access_token: token, active: true)
          self.current_client = client
        end
      end
  end
end

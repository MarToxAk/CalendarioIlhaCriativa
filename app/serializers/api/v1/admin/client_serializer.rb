# frozen_string_literal: true

module Api::V1::Admin::ClientSerializer
  def self.serialize(client, include_credentials: false, portal_host: nil)
    data = {
      id:         client.id,
      name:       client.name,
      active:     client.active,
      created_at: client.created_at
    }
    if include_credentials
      data[:password]   = client.password_plain
      data[:portal_url] = "#{portal_host}/c/#{client.access_token}"
    end
    data
  end

  def self.serialize_collection(clients)
    clients.map { |c| serialize(c) }
  end
end

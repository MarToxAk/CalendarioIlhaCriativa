class Client < ApplicationRecord
  has_secure_token :access_token
  has_secure_password

  has_many :artes, dependent: :destroy

  validates :name, presence: true
  validates :access_token, presence: true, uniqueness: true

  def token_version
    raise "access_token is nil — client #{id} has no valid token" if access_token.nil?
    access_token.first(8)
  end
end

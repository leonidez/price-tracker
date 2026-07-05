# Single shared bearer-token auth for this personal app.
#
# Every request must send `Authorization: Bearer <token>` where the token
# equals ENV["API_TOKEN"]. Comparison is constant-time. Missing or wrong
# token -> 401 with body {"error":{"code":"unauthorized"}}.
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate!
  end

  private

  def authenticate!
    render_unauthorized unless valid_token?
  end

  def valid_token?
    expected = ENV["API_TOKEN"].to_s
    provided = bearer_token.to_s
    return false if expected.empty? || provided.empty?

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def bearer_token
    request.authorization.to_s[/\ABearer (.+)\z/, 1]
  end

  def render_unauthorized
    render json: { error: { code: "unauthorized" } }, status: :unauthorized
  end
end

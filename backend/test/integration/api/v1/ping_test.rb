require "test_helper"

module Api
  module V1
    class PingTest < ActionDispatch::IntegrationTest
      def auth_header(token)
        { "Authorization" => "Bearer #{token}" }
      end

      test "no token returns 401 with error envelope" do
        get "/api/v1/ping"
        assert_response :unauthorized
        assert_equal({ "error" => { "code" => "unauthorized" } }, response.parsed_body)
      end

      test "bad token returns 401" do
        get "/api/v1/ping", headers: auth_header("wrong-token")
        assert_response :unauthorized
        assert_equal({ "error" => { "code" => "unauthorized" } }, response.parsed_body)
      end

      test "good token returns 200 and ok payload" do
        get "/api/v1/ping", headers: auth_header(ENV.fetch("API_TOKEN"))
        assert_response :ok
        assert_equal({ "ok" => true }, response.parsed_body)
      end

      test "malformed authorization header returns 401" do
        get "/api/v1/ping", headers: { "Authorization" => ENV.fetch("API_TOKEN") }
        assert_response :unauthorized
      end

      test "health check is reachable without a token" do
        get "/up"
        assert_response :ok
      end
    end
  end
end

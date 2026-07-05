require "test_helper"

module Api
  module V1
    class DevicesTest < ActionDispatch::IntegrationTest
      include ApiHelpers

      test "requires authentication" do
        post "/api/v1/devices", params: { expo_push_token: "ExponentPushToken[x]", platform: "ios" }, as: :json
        assert_response :unauthorized
      end

      test "creates a device on first registration, upserts on repeat" do
        assert_difference("Device.count", 1) do
          post "/api/v1/devices", params: { expo_push_token: "ExponentPushToken[abc]", platform: "ios" }, headers: auth_headers, as: :json
        end
        assert_response :created

        # Same token again -> upsert (no new row), 200, still active.
        assert_no_difference("Device.count") do
          post "/api/v1/devices", params: { expo_push_token: "ExponentPushToken[abc]", platform: "ios" }, headers: auth_headers, as: :json
        end
        assert_response :ok

        device = Device.find_by(expo_push_token: "ExponentPushToken[abc]")
        assert device.active
        assert_not_nil device.last_seen_at
      end

      test "422 when the token is missing" do
        post "/api/v1/devices", params: { platform: "ios" }, headers: auth_headers, as: :json
        assert_response :unprocessable_entity
      end
    end
  end
end

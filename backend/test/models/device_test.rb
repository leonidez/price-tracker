require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  test "valid device" do
    assert Device.new(expo_push_token: "ExponentPushToken[abc]").valid?
  end

  test "requires expo_push_token" do
    assert_not Device.new.valid?
  end

  test "expo_push_token is unique" do
    Device.create!(expo_push_token: "ExponentPushToken[dup]")
    assert_not Device.new(expo_push_token: "ExponentPushToken[dup]").valid?
  end
end

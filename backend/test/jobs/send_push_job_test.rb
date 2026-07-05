require "test_helper"

class SendPushJobTest < ActiveJob::TestCase
  SEND_URL = "https://exp.host/--/api/v2/push/send".freeze

  setup do
    @listing = listings(:cola_walmart)
    @watch = @listing.watches.create!(baseline_price_cents: 10_000, active: true)
    @device = Device.create!(expo_push_token: "ExponentPushToken[abc]", platform: "ios", active: true)
    point = @listing.price_points.create!(price_cents: 7_500, currency: "USD", checked_at: Time.current)
    @notification = @watch.notifications.create!(kind: "price_alert", price_point: point, notified_price_cents: 7_500)
  end

  def stub_send(tickets)
    stub_request(:post, SEND_URL).to_return(
      status: 200, body: { data: tickets }.to_json, headers: { "Content-Type" => "application/json" }
    )
  end

  test "happy path marks the notification sent and schedules a receipt check" do
    stub_send([ { status: "ok", id: "ticket-1" } ])

    assert_enqueued_with(job: CheckPushReceiptsJob) do
      SendPushJob.perform_now(@notification)
    end

    assert_equal "sent", @notification.reload.push_status
    assert_not_nil @notification.sent_at
    assert @device.reload.active
    assert_requested :post, SEND_URL
  end

  test "DeviceNotRegistered ticket deactivates the device" do
    stub_send([ { status: "error", details: { error: "DeviceNotRegistered" } } ])
    SendPushJob.perform_now(@notification)
    assert_not @device.reload.active
  end

  test "already-sent notification does not call Expo again" do
    @notification.update!(push_status: "sent")
    SendPushJob.perform_now(@notification)
    assert_not_requested :post, SEND_URL
  end

  test "no active devices means no call" do
    @device.update!(active: false)
    SendPushJob.perform_now(@notification)
    assert_not_requested :post, SEND_URL
  end
end

class CheckPushReceiptsJobTest < ActiveJob::TestCase
  RECEIPTS_URL = "https://exp.host/--/api/v2/push/getReceipts".freeze

  test "DeviceNotRegistered receipt deactivates the mapped device" do
    device = Device.create!(expo_push_token: "ExponentPushToken[dead]", active: true)
    stub_request(:post, RECEIPTS_URL).to_return(
      status: 200,
      body: { data: { "ticket-1" => { status: "error", details: { error: "DeviceNotRegistered" } } } }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    CheckPushReceiptsJob.perform_now({ "ticket-1" => device.id })
    assert_not device.reload.active
  end
end

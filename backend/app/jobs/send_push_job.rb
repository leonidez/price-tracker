# Deliver one notification to all active devices via Expo. Idempotent: a
# notification already marked "sent" is skipped. Dead tokens (DeviceNotRegistered)
# are deactivated. Receipts are checked later by CheckPushReceiptsJob.
class SendPushJob < ApplicationJob
  queue_as :default
  retry_on Http::FetchError, wait: :polynomially_longer, attempts: 3

  def perform(notification)
    return if notification.push_status == "sent"

    devices = Device.where(active: true).to_a
    return if devices.empty?

    messages = devices.map { |device| message_for(device, notification) }
    tickets = ExpoPush::Client.new.send_messages(messages)

    ticket_device_map = process_tickets(devices, tickets)
    notification.update!(push_status: "sent", sent_at: Time.current)

    CheckPushReceiptsJob.set(wait: 30.minutes).perform_later(ticket_device_map) if ticket_device_map.any?
  end

  private

  def message_for(device, notification)
    {
      to: device.expo_push_token,
      title: PushCopy.title(notification),
      body: PushCopy.body(notification),
      sound: "default",
      data: { watch_id: notification.watch_id }
    }
  end

  # Deactivate dead tokens now; collect ok ticket ids -> device id for receipts.
  def process_tickets(devices, tickets)
    ticket_device_map = {}
    devices.each_with_index do |device, index|
      ticket = tickets[index] || {}
      if dead_token?(ticket)
        device.update!(active: false)
      elsif ticket["status"] == "ok" && ticket["id"]
        ticket_device_map[ticket["id"]] = device.id
      end
    end
    ticket_device_map
  end

  def dead_token?(ticket)
    ticket["status"] == "error" && ticket.dig("details", "error") == "DeviceNotRegistered"
  end
end

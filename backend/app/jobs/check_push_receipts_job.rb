# Check Expo push receipts ~30 minutes after sending. Deactivates devices whose
# receipt reports DeviceNotRegistered. Other receipt errors are logged and
# ignored (keep it simple).
class CheckPushReceiptsJob < ApplicationJob
  queue_as :default
  retry_on Http::FetchError, wait: :polynomially_longer, attempts: 3

  # ticket_device_map: { ticket_id => device_id }
  def perform(ticket_device_map)
    return if ticket_device_map.blank?

    receipts = ExpoPush::Client.new.get_receipts(ticket_device_map.keys)
    receipts.each do |ticket_id, receipt|
      next unless receipt.is_a?(Hash)

      if receipt["status"] == "error" && receipt.dig("details", "error") == "DeviceNotRegistered"
        Device.where(id: ticket_device_map[ticket_id]).update_all(active: false)
      elsif receipt["status"] == "error"
        Rails.logger.info("[push] receipt error for #{ticket_id}: #{receipt.dig('details', 'error')}")
      end
    end
  end
end

namespace :push do
  desc "Send a test push to all active devices (run first when wiring the phone in #15)"
  task test: :environment do
    devices = Device.where(active: true)
    if devices.empty?
      puts "No active devices registered. Register the phone first (POST /api/v1/devices)."
      next
    end

    messages = devices.map do |device|
      { to: device.expo_push_token, title: "Price Tracker connected ✅", body: "Push is working.", sound: "default" }
    end

    tickets = ExpoPush::Client.new.send_messages(messages)
    puts "Sent #{messages.size} message(s). Tickets:"
    pp tickets
  rescue Http::FetchError => e
    warn "push failed: #{e.message}"
  end
end

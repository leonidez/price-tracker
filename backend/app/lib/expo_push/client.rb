require "faraday"
require "json"

module ExpoPush
  # Thin client for Expo's push service. No APNs/FCM setup needed — we just POST
  # JSON. Network/HTTP failures surface as Http::FetchError so jobs can retry.
  class Client
    SEND_URL = "https://exp.host/--/api/v2/push/send".freeze
    RECEIPTS_URL = "https://exp.host/--/api/v2/push/getReceipts".freeze
    TIMEOUT = 15

    # messages: array of Expo message hashes. Returns the array of tickets.
    def send_messages(messages)
      post(SEND_URL, messages).fetch("data", [])
    end

    # ids: array of ticket ids. Returns the receipts hash {ticket_id => receipt}.
    def get_receipts(ids)
      post(RECEIPTS_URL, { "ids" => ids }).fetch("data", {})
    end

    private

    def post(url, body)
      response = connection.post(url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers["Accept"] = "application/json"
        req.options.timeout = TIMEOUT
        req.options.open_timeout = TIMEOUT
        req.body = JSON.generate(body)
      end
      raise Http::FetchError, "Expo push HTTP #{response.status}" unless response.success?

      JSON.parse(response.body.to_s)
    rescue Faraday::Error => e
      raise Http::FetchError, "Expo push request failed: #{e.message}"
    rescue JSON::ParserError => e
      raise Http::FetchError, "Expo push returned invalid JSON: #{e.message}"
    end

    def connection
      Faraday.new
    end
  end
end

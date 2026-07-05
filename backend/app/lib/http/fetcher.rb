require "faraday"
require "faraday/follow_redirects"

module Http
  # Polite HTTP GET with realistic browser headers, redirect following, and
  # clean block/failure signaling. No live HTTP in tests — stub with WebMock.
  module Fetcher
    module_function

    DEFAULT_HEADERS = {
      "User-Agent" =>
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
        "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
      "Accept" =>
        "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language" => "en-US,en;q=0.9"
    }.freeze

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 10
    MAX_REDIRECTS = 5

    # get(url, headers:, blocked_if:) -> Http::Response
    # Raises Http::BlockedError on 403/429 or a matching challenge marker;
    # Http::FetchError on 5xx / timeouts / connection errors.
    def get(url, headers: {}, blocked_if: nil)
      response = connection.get(url) do |req|
        req.headers.merge!(DEFAULT_HEADERS.merge(headers))
        req.options.open_timeout = OPEN_TIMEOUT
        req.options.timeout = READ_TIMEOUT
      end

      body = response.body.to_s
      status = response.status

      raise BlockedError, "blocked (HTTP #{status}) fetching #{url}" if status.in?([ 403, 429 ])
      raise BlockedError, "challenge marker matched fetching #{url}" if blocked_if && body.match?(blocked_if)
      raise FetchError, "server error (HTTP #{status}) fetching #{url}" if status >= 500

      Response.new(status: status, body: body, final_url: response.env.url.to_s)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise FetchError, "connection error fetching #{url}: #{e.message}"
    end

    def connection
      Faraday.new do |f|
        f.response :follow_redirects, limit: MAX_REDIRECTS
        f.adapter Faraday.default_adapter
      end
    end
  end
end

require "test_helper"

class HttpFetcherTest < ActiveSupport::TestCase
  URL = "https://store.example.com/product"

  test "returns a Response on 200" do
    stub_request(:get, URL).to_return(status: 200, body: "hello")
    res = Http::Fetcher.get(URL)
    assert_equal 200, res.status
    assert_equal "hello", res.body
    assert_equal "#{URL}", res.final_url.chomp("/")
  end

  test "sends realistic browser headers" do
    stub_request(:get, URL).to_return(status: 200, body: "ok")
    Http::Fetcher.get(URL)
    assert_requested(:get, URL) do |req|
      req.headers["User-Agent"].include?("Chrome") &&
        req.headers["Accept-Language"].start_with?("en-US")
    end
  end

  test "merges caller headers" do
    stub_request(:get, URL).with(headers: { "X-Test" => "1" }).to_return(status: 200, body: "ok")
    assert_equal "ok", Http::Fetcher.get(URL, headers: { "X-Test" => "1" }).body
  end

  test "raises BlockedError on 403 and 429" do
    stub_request(:get, URL).to_return(status: 403)
    assert_raises(Http::BlockedError) { Http::Fetcher.get(URL) }

    stub_request(:get, URL).to_return(status: 429)
    assert_raises(Http::BlockedError) { Http::Fetcher.get(URL) }
  end

  test "raises BlockedError when the challenge marker matches" do
    stub_request(:get, URL).to_return(status: 200, body: "Robot or human? Press and hold")
    assert_raises(Http::BlockedError) do
      Http::Fetcher.get(URL, blocked_if: /Robot or human/)
    end
  end

  test "raises FetchError on 5xx" do
    stub_request(:get, URL).to_return(status: 503)
    assert_raises(Http::FetchError) { Http::Fetcher.get(URL) }
  end

  test "raises FetchError on timeout" do
    stub_request(:get, URL).to_timeout
    assert_raises(Http::FetchError) { Http::Fetcher.get(URL) }
  end

  test "follows redirects and reports the final url" do
    stub_request(:get, URL).to_return(status: 302, headers: { "Location" => "https://store.example.com/final" })
    stub_request(:get, "https://store.example.com/final").to_return(status: 200, body: "arrived")
    res = Http::Fetcher.get(URL)
    assert_equal "arrived", res.body
    assert_equal "https://store.example.com/final", res.final_url
  end
end

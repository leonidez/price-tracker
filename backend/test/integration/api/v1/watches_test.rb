require "test_helper"

module Api
  module V1
    class WatchesTest < ActionDispatch::IntegrationTest
      include ApiHelpers

      test "index requires authentication" do
        get "/api/v1/watches"
        assert_response :unauthorized
      end

      test "create from resolution builds product, listing, price point, watch, and rules" do
        assert_difference([ "Watch.count", "Product.count", "Listing.count", "PricePoint.count" ], 1) do
          post "/api/v1/watches",
               params: {
                 barcode: "036000291452",
                 store_id: stores(:walmart).id,
                 resolution: {
                   url: "https://www.walmart.com/ip/acme/1", title: "Acme Cola",
                   image_url: "https://img/cola.jpg", price_cents: 1299, currency: "USD",
                   verified: true, store_ref: { "us_item_id" => "1" }
                 },
                 rules: [ { kind: "below_price", value_cents: 8000 } ]
               },
               headers: auth_headers, as: :json
        end
        assert_response :created
        body = response.parsed_body
        assert_equal 1299, body["baseline_price_cents"]
        assert_equal "0036000291452", body.dig("product", "gtin13")
        assert_equal 1299, body.dig("latest_price", "price_cents")
        assert_equal 1, body["rules"].size
        assert_equal "below_price", body["rules"].first["kind"]
      end

      test "create from URL builds a product-less listing via the adapter check" do
        stub_request(:get, "https://example.com/thing")
          .to_return(status: 200, body: Rails.root.join("test/fixtures/http/jsonld_graph.html").read)

        assert_difference("Watch.count", 1) do
          post "/api/v1/watches",
               params: {
                 url: "https://example.com/thing",
                 store_id: stores(:generic).id,
                 name: "My Thing",
                 rules: [ { kind: "percent_drop", value_pct: 25 } ]
               },
               headers: auth_headers, as: :json
        end
        assert_response :created
        body = response.parsed_body
        assert_equal "My Thing", body.dig("product", "name")
        assert_nil body.dig("product", "gtin13")
        assert_equal "My Thing", body.dig("listing", "display_name")
        assert_equal 1299, body.dig("latest_price", "price_cents")
        assert_equal "percent_drop", body["rules"].first["kind"]
      end

      test "dry_run returns the resolved price without persisting" do
        stub_request(:get, "https://example.com/dry")
          .to_return(status: 200, body: Rails.root.join("test/fixtures/http/jsonld_graph.html").read)

        assert_no_difference([ "Watch.count", "Listing.count", "PricePoint.count" ]) do
          post "/api/v1/watches",
               params: { url: "https://example.com/dry", store_id: stores(:generic).id, dry_run: true },
               headers: auth_headers, as: :json
        end
        assert_response :ok
        body = response.parsed_body
        assert_equal true, body["dry_run"]
        assert_equal 1299, body["price_cents"]
        assert_equal "USD", body["currency"]
      end

      test "dry_run maps an unreadable page to 422 parse_failed" do
        stub_request(:get, "https://example.com/drynp")
          .to_return(status: 200, body: Rails.root.join("test/fixtures/http/no_price.html").read)

        post "/api/v1/watches",
             params: { url: "https://example.com/drynp", store_id: stores(:generic).id, dry_run: true },
             headers: auth_headers, as: :json
        assert_response :unprocessable_entity
        assert_equal "parse_failed", response.parsed_body.dig("error", "code")
      end

      test "create requires at least one rule" do
        post "/api/v1/watches",
             params: { url: "https://example.com/x", store_id: stores(:generic).id, rules: [] },
             headers: auth_headers, as: :json
        assert_response :unprocessable_entity
        assert_equal "invalid_rules", response.parsed_body.dig("error", "code")
      end

      test "create from URL returns 422 parse_failed when no price can be read" do
        stub_request(:get, "https://example.com/np")
          .to_return(status: 200, body: Rails.root.join("test/fixtures/http/no_price.html").read)

        post "/api/v1/watches",
             params: { url: "https://example.com/np", store_id: stores(:generic).id, rules: [ { kind: "below_price", value_cents: 100 } ] },
             headers: auth_headers, as: :json
        assert_response :unprocessable_entity
        assert_equal "parse_failed", response.parsed_body.dig("error", "code")
      end

      test "show returns price history and notifications" do
        watch = build_url_watch
        watch.notifications.create!(kind: "price_alert", notified_price_cents: 1000)

        get "/api/v1/watches/#{watch.id}", headers: auth_headers
        assert_response :ok
        body = response.parsed_body
        assert body["price_points"].is_a?(Array)
        assert_equal 1, body["notifications"].size
        assert_equal "price_alert", body["notifications"].first["kind"]
      end

      test "update replaces the full rule set atomically" do
        watch = build_url_watch
        watch.alert_rules.create!(kind: "below_price", value_cents: 5000)

        patch "/api/v1/watches/#{watch.id}",
              params: { baseline_price_cents: 4200, active: false, rules: [ { kind: "amount_drop", value_cents: 300 } ] },
              headers: auth_headers, as: :json
        assert_response :ok
        body = response.parsed_body
        assert_equal 4200, body["baseline_price_cents"]
        assert_equal false, body["active"]
        assert_equal 1, body["rules"].size
        assert_equal "amount_drop", body["rules"].first["kind"]
        assert_equal 1, watch.reload.alert_rules.count
      end

      test "destroy removes the watch and its now-orphaned listing" do
        watch = build_url_watch
        listing_id = watch.listing_id

        assert_difference([ "Watch.count", "Listing.count" ], -1) do
          delete "/api/v1/watches/#{watch.id}", headers: auth_headers
        end
        assert_response :no_content
        assert_not Listing.exists?(listing_id)
      end

      private

      # Build a manual URL watch directly (no HTTP) for show/update/destroy tests.
      def build_url_watch
        listing = Listing.create!(store: stores(:generic), url: "https://example.com/w", display_name: "Widget", status: "active")
        listing.price_points.create!(price_cents: 2000, currency: "USD", in_stock: true, checked_at: Time.current, source: "resolution")
        Watch.create!(listing: listing, baseline_price_cents: 2000)
      end
    end
  end
end

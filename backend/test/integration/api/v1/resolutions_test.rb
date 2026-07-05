require "test_helper"

module Api
  module V1
    class ResolutionsTest < ActionDispatch::IntegrationTest
      include ApiHelpers

      setup do
        StoreAdapters.register("fake", FakeAdapter)
        @store = Store.create!(name: "Fake", slug: "fake", domain: "fake.test", adapter: "fake")
      end

      teardown do
        FakeAdapter.reset!
        StoreAdapters.reset_registry!
      end

      test "requires authentication" do
        post "/api/v1/resolutions", params: { barcode: "036000291452", store_id: @store.id }, as: :json
        assert_response :unauthorized
      end

      test "422 invalid_barcode when the code cannot be normalized" do
        post "/api/v1/resolutions", params: { barcode: "not-a-code", store_id: @store.id }, headers: auth_headers, as: :json
        assert_response :unprocessable_entity
        assert_equal "invalid_barcode", response.parsed_body.dig("error", "code")
      end

      test "200 with product and resolution on success" do
        FakeAdapter.resolve_handler = lambda do |_gtin, _hint|
          StoreAdapters::Resolution.new(
            url: "https://fake.test/p/1", title: "Acme Cola", image_url: "https://img/cola.jpg",
            price_cents: 1299, currency: "USD", store_ref: { "id" => "1" }, verified: true
          )
        end

        post "/api/v1/resolutions", params: { barcode: "036000291452", store_id: @store.id }, headers: auth_headers, as: :json
        assert_response :ok
        body = response.parsed_body
        assert_equal "0036000291452", body.dig("product", "gtin13")
        assert_equal "Acme Cola", body.dig("product", "name")
        assert_equal 1299, body.dig("resolution", "price_cents")
        assert_equal true, body.dig("resolution", "verified")
      end

      test "maps ResolveFailed to a 422 with the failure code" do
        FakeAdapter.resolve_handler = ->(_g, _h) { raise StoreAdapters::ResolveFailed.new(code: :not_found) }
        post "/api/v1/resolutions", params: { barcode: "036000291452", store_id: @store.id }, headers: auth_headers, as: :json
        assert_response :unprocessable_entity
        assert_equal "not_found", response.parsed_body.dig("error", "code")
      end
    end
  end
end

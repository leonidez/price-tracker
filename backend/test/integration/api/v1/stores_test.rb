require "test_helper"

module Api
  module V1
    class StoresTest < ActionDispatch::IntegrationTest
      include ApiHelpers

      test "requires authentication" do
        get "/api/v1/stores"
        assert_response :unauthorized
      end

      test "lists active stores with supports_resolution" do
        get "/api/v1/stores", headers: auth_headers
        assert_response :ok

        by_slug = response.parsed_body.index_by { |store| store["slug"] }
        assert_equal false, by_slug.fetch("generic")["supports_resolution"]
        assert_equal true, by_slug.fetch("walmart")["supports_resolution"]
        assert by_slug.values.all? { |store| store.key?("id") && store.key?("name") }
      end
    end
  end
end

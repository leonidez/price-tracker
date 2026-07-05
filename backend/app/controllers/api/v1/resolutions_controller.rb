module Api
  module V1
    class ResolutionsController < ApplicationController
      # POST /api/v1/resolutions {barcode, symbology?, store_id}
      def create
        gtin13 = Gtin.normalize(params[:barcode], symbology: params[:symbology])
        return render_error("invalid_barcode", message: "unrecognized barcode", status: :unprocessable_entity) if gtin13.nil?

        store = Store.find(params[:store_id])
        resolution = StoreAdapters.for(store).resolve(gtin13: gtin13, hint: params[:name])
        raise StoreAdapters::ResolveFailed.new(code: :not_found) if resolution.nil?

        render json: ResolutionSerializer.new(gtin13, resolution).as_json
      rescue StoreAdapters::ResolveFailed => e
        render_error(e.code.to_s, message: e.message, status: :unprocessable_entity)
      rescue StoreAdapters::ConfigurationError => e
        render_error("configuration_error", message: e.message, status: :unprocessable_entity)
      rescue Http::BlockedError => e
        render_error("blocked", message: e.message, status: :unprocessable_entity)
      end
    end
  end
end

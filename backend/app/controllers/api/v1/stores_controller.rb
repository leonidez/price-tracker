module Api
  module V1
    class StoresController < ApplicationController
      # GET /api/v1/stores -> active stores
      def index
        stores = Store.where(active: true).order(:name)
        render json: stores.map { |store| StoreSerializer.new(store).as_json }
      end
    end
  end
end

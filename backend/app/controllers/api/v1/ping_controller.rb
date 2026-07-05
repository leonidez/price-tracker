module Api
  module V1
    class PingController < ApplicationController
      # GET /api/v1/ping -> {"ok":true} (authenticated smoke endpoint)
      def show
        render json: { ok: true }
      end
    end
  end
end

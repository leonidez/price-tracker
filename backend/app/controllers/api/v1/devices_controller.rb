module Api
  module V1
    class DevicesController < ApplicationController
      # POST /api/v1/devices {expo_push_token, platform} -> upsert on token
      def create
        token = params[:expo_push_token].to_s
        return render_error("invalid", message: "expo_push_token is required", status: :unprocessable_entity) if token.blank?

        device = Device.find_or_initialize_by(expo_push_token: token)
        created = device.new_record?
        device.platform = params[:platform] if params[:platform].present?
        device.active = true
        device.last_seen_at = Time.current
        device.save!

        render json: { id: device.id, active: device.active }, status: created ? :created : :ok
      end
    end
  end
end

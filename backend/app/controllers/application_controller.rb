class ApplicationController < ActionController::API
  include Authenticatable

  # Consistent error envelope: {"error":{"code":"...","message":"..."}}.
  rescue_from ActiveRecord::RecordNotFound do |error|
    render_error("not_found", message: error.message, status: :not_found)
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render_error("invalid", message: error.record.errors.full_messages.to_sentence, status: :unprocessable_entity)
  end

  rescue_from ActionController::ParameterMissing do |error|
    render_error("parameter_missing", message: error.message, status: :unprocessable_entity)
  end

  private

  def render_error(code, status:, message: nil)
    render json: { error: { code: code, message: message }.compact }, status: status
  end
end

module ApiHelpers
  def auth_headers(extra = {})
    { "Authorization" => "Bearer #{ENV.fetch('API_TOKEN')}" }.merge(extra)
  end
end

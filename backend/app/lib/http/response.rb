module Http
  # Minimal successful-fetch value object.
  Response = Data.define(:status, :body, :final_url)
end

# Load and validate the rulebook at boot so a schema-invalid item fails fast
# everywhere (dev, test, CI, production) instead of surfacing mid-request.
Rails.application.config.after_initialize do
  Fogbell::Rulebook.instance
end

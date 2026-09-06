# frozen_string_literal: true

# Copy to config/initializers/swagger_autogenerate.rb and adjust as needed.
# Everything is optional — omit this file to use project-agnostic defaults.

SwaggerAutogenerate.configure do |config|
  # rswag-api / rswag-ui usually serve files from swagger/v1
  config.default_path = 'swagger/v1'

  config.info_title = 'My API'
  config.info_description = 'API documentation generated from request specs'
  config.info_version = '1.0.0'
  config.servers = [{ 'url' => 'http://localhost:3000' }]

  # Example JWT security for OpenAPI / rswag-ui "Authorize"
  # config.security_schemes = {
  #   'bearerAuth' => {
  #     'type' => 'http',
  #     'scheme' => 'bearer',
  #     'bearerFormat' => 'JWT'
  #   }
  # }
  # config.security = [{ 'bearerAuth' => [] }]

  config.with_multiple_examples = true
  config.with_rspec_examples = true
  config.action_for_old_examples = :append # :replace
end

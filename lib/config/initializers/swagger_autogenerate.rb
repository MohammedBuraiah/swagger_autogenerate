Rails.application.config.after_initialize do
  if Rails.env.test? && ENV['SWAGGER'].present?
    ApplicationController.include(SwaggerAutogenerate)
  end
end

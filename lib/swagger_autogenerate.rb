# frozen_string_literal: true

module SwaggerAutogenerate
  extend ::ActiveSupport::Concern
  require_relative 'swagger_autogenerate/swagger_trace.rb'

  included do
    def process_action(*args)
      super

      if ENV[SwaggerTrace.swagger_environment_variable].present? && Rails.env.send("#{SwaggerTrace.environment_name.to_s}?")
        SwaggerTrace.new(request, response).call
      end
    end
  end
end

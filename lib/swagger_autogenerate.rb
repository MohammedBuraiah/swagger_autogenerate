# frozen_string_literal: true

module SwaggerAutogenerate
  extend ::ActiveSupport::Concern
  require_relative 'swagger_autogenerate/swagger_trace.rb'

  included do
    if defined?(Rails) && Rails.env.test? && ENV[SwaggerTrace::SWAGGER_ENVIRONMENT_VARIABLE].present?
      def process_action(*args)
        super

        SwaggerTrace.new(request, response).call
      end
    end
  end
end

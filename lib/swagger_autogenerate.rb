# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'active_support/concern'
require 'yaml'
require 'json'
require 'date'

require_relative 'swagger_autogenerate/version'
require_relative 'swagger_autogenerate/configuration'
require_relative 'swagger_autogenerate/swagger_trace'

module SwaggerAutogenerate
  extend ::ActiveSupport::Concern

  included do
    def process_action(*args)
      super

      SwaggerTrace.new(request, response).call if SwaggerAutogenerate.generate?
    end
  end

  class << self
    # True when env vars ask for generation and we are in the configured environment.
    def generate?
      env_requested? && test_environment?
    end

    alias allow_swagger? generate?

    def env_requested?
      path_var = configuration.swagger_path_environment_variable
      generate_var = configuration.generate_swagger_environment_variable

      ENV[path_var].present? || ENV[generate_var].present?
    end

    def test_environment?
      env_name = configuration.environment_name.to_s
      return true unless defined?(Rails)

      Rails.env.to_s == env_name
    end
  end
end

require_relative 'swagger_autogenerate/railtie' if defined?(Rails::Railtie)

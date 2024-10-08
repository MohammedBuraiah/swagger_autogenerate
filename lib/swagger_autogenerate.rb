# frozen_string_literal: true

module SwaggerAutogenerate
  extend ::ActiveSupport::Concern
  require_relative 'swagger_autogenerate/swagger_trace.rb'

  included do
    def process_action(*args)
      super

      if SwaggerAutogenerate.allow_swagger?
        SwaggerTrace.new(request, response).call
      end
    end
  end

  def self.allow_swagger?
    (ENV[SwaggerTrace.swagger_path_environment_variable].present? || ENV[SwaggerTrace.generate_swagger_environment_variable].present?) &&
    Rails.env.send("#{SwaggerTrace.environment_name.to_s}?")
  end
end

if defined?(RSpec) && SwaggerAutogenerate.allow_swagger?
  require 'rspec/rails'

  RSpec.configure do |config|
    config.before(:each) do |example|
      SwaggerAutogenerate::SwaggerTrace.rspec_description = example&.metadata.dig(:example_group, :description)
    end
  end
end

# frozen_string_literal: true

module SwaggerAutogenerate
  class Railtie < ::Rails::Railtie
    initializer 'swagger_autogenerate.configure' do
      config.after_initialize do
        setup_rspec_hook!
        auto_include_controller!
      end
    end

    private

    def setup_rspec_hook!
      return unless defined?(RSpec)

      RSpec.configure do |rspec|
        rspec.before(:each) do |example|
          next unless SwaggerAutogenerate.generate?

          SwaggerAutogenerate::SwaggerTrace.rspec_description =
            example&.metadata&.dig(:example_group, :description)
        end
      end
    end

    def auto_include_controller!
      return unless SwaggerAutogenerate.configuration.auto_include
      return unless SwaggerAutogenerate.test_environment?
      return unless defined?(ApplicationController)
      return if ApplicationController.included_modules.include?(SwaggerAutogenerate)

      ApplicationController.include(SwaggerAutogenerate)
    end
  end
end

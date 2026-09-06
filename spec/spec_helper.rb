# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'yaml'
require 'json'
require 'date'
require 'fileutils'
require 'tmpdir'
require 'pathname'

# Minimal Rails stub for unit tests
module Rails
  class << self
    attr_accessor :root

    def env
      @env ||= ActiveSupport::StringInquirer.new('test')
    end

    def env=(value)
      @env = value.is_a?(ActiveSupport::StringInquirer) ? value : ActiveSupport::StringInquirer.new(value.to_s)
    end
  end

  class Application
    def self.module_parent_name
      'DemoApp'
    end
  end

  def self.application
    @application ||= Application.new
  end
end

require 'swagger_autogenerate'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    SwaggerAutogenerate.reset_configuration!
    SwaggerAutogenerate::SwaggerTrace.rspec_description = nil
    Rails.env = 'test'
    ENV.delete('SWAGGER_GENERATE_PATH')
    ENV.delete('SWAGGER_GENERATE')
    ENV.delete('tag')
  end
end

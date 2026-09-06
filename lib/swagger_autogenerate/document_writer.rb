# frozen_string_literal: true

require 'fileutils'

module SwaggerAutogenerate
  # Resolves output path and reads/writes Swagger YAML documents.
  class DocumentWriter
    def initialize(config:, tags:, request:)
      @config = config
      @tags = tags
      @request = request
    end

    def location
      return @location if defined?(@location)

      generate_env = config.generate_swagger_environment_variable
      path_env = config.swagger_path_environment_variable

      @location =
        if ENV[generate_env].present?
          directory = Rails.root.join(config.resolved_default_path).to_s
          FileUtils.mkdir_p(directory)
          File.join(directory, "#{Helpers.snake_case(tags&.first)}.yaml")
        elsif ENV[path_env].to_s.match?(/\.(ya?ml)\z/i)
          Rails.root.join(ENV.fetch(path_env)).to_s
        else
          directory = Rails.root.join(ENV.fetch(path_env, config.resolved_default_path)).to_s
          FileUtils.mkdir_p(directory)
          File.join(directory, "#{Helpers.snake_case(tags&.first)}.yaml")
        end
    end

    def exist?
      File.exist?(location)
    end

    def read
      return nil unless exist?

      Helpers.load_yaml(location)
    end

    def write(data)
      File.write(location, Helpers.dump_yaml(data))
    end

    def ensure_exists!
      write({ 'paths' => {} }) unless exist?
    end

    private

    attr_reader :config, :tags, :request
  end
end

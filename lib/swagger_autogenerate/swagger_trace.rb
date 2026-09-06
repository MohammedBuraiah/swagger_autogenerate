# frozen_string_literal: true

require_relative 'configuration'
require_relative 'helpers'
require_relative 'schema_builder'
require_relative 'parameter_builder'
require_relative 'response_builder'
require_relative 'path_normalizer'
require_relative 'document_writer'
require_relative 'yaml_merger'

module SwaggerAutogenerate
  # Observes one request/response pair and updates the Swagger YAML file.
  class SwaggerTrace
    class << self
      attr_accessor :rspec_description

      def swagger_path_environment_variable
        ::SwaggerAutogenerate.configuration.swagger_path_environment_variable
      end

      def generate_swagger_environment_variable
        ::SwaggerAutogenerate.configuration.generate_swagger_environment_variable
      end

      def environment_name
        ::SwaggerAutogenerate.configuration.environment_name
      end
    end

    def initialize(request, response)
      @config = ::SwaggerAutogenerate.configuration
      @request = request
      @response = response
      @schema = SchemaBuilder.new
      @parameter_builder = ParameterBuilder.new(request, schema_builder: @schema)
      @paths = {}
      @@removed_examples ||= []
    end

    def call
      @current_path = PathNormalizer.call(request)
      replace_old_examples_if_needed
      build_path_entry
      write_document
    end

    def swagger_path_environment_variable
      self.class.swagger_path_environment_variable
    end

    def generate_swagger_environment_variable
      self.class.generate_swagger_environment_variable
    end

    def environment_name
      self.class.environment_name
    end

    private

    attr_reader :request, :response, :config, :schema, :parameter_builder, :paths, :current_path

    def build_path_entry
      method = request.method.to_s.downcase
      hash = {
        method => {
          'tags' => tags,
          'summary' => summary,
          'parameters' => parameter_builder.parameters,
          'responses' => {},
          'security' => current_security
        }
      }

      body = parameter_builder.request_body
      hash[method]['requestBody'] = body if body.present?

      paths[current_path] ||= {}
      paths[current_path].merge!(hash)
    end

    def write_document
      method = request.method.downcase
      paths[current_path][method]['responses'] = swagger_response if paths.dig(current_path, method)

      if document_writer.exist?
        edit_file
      else
        create_file
      end
    end

    def create_file
      data = config.with_config ? deep_dup(config.resolved_swagger_config) : {}
      data['paths'] = paths
      merger = build_merger(data)
      merger.organize_result!(data['paths'])
      merger.merge_example!(data['paths'], with_schema_properties: true)
      document_writer.write(data)
    end

    def edit_file
      yaml_file = document_writer.read
      return create_file if yaml_file.nil? || yaml_file['paths'].nil?

      yaml_file.merge!(deep_dup(config.resolved_swagger_config)) if config.with_config
      build_merger(yaml_file).apply!
      document_writer.write(yaml_file)
    end

    def build_merger(yaml_file)
      YamlMerger.new(
        yaml_file: yaml_file,
        paths: paths,
        current_path: current_path,
        request: request,
        response: response,
        swagger_response: swagger_response,
        example_title: example_title,
        config: config,
        schema_builder: schema,
        parameter_builder: parameter_builder,
        tags: tags,
        summary: summary,
        security: current_security
      )
    end

    def document_writer
      @document_writer ||= DocumentWriter.new(
        config: config,
        tags: [file_tag],
        request: request
      )
    end

    def replace_old_examples_if_needed
      return unless config.action_for_old_examples == :replace

      document_writer.ensure_exists!
      marker = { current_path => request.method.to_s.downcase }
      return if @@removed_examples.include?(marker)

      current_yaml = document_writer.read || { 'paths' => {} }
      current_yaml['paths'] ||= {}
      current_yaml['paths'][current_path] = { request.method.to_s.downcase => {} }
      document_writer.write(current_yaml)
      @@removed_examples << marker
    end

    # Used for YAML filename — stable, does not depend on reading the file.
    def file_tag
      ENV['tag'].presence || controller_name&.capitalize || 'api'
    end

    def tags
      existing = existing_operation&.dig('tags')&.last
      [existing&.capitalize || file_tag]
    end

    def summary
      existing_operation&.dig('summary') || build_summary(request.method.downcase, current_path)
    end

    def current_security
      existing_operation&.dig('security') || config.security
    end

    def existing_operation
      return @existing_operation if defined?(@existing_operation)

      @existing_operation =
        if document_writer.exist?
          document_writer.read&.dig('paths', current_path, request.method.downcase)
        end
    end

    def build_summary(method, path)
      resource = Helpers.format_path_to_title(path)
      id_segment = path.include?('{')

      case method.upcase
      when 'GET' then id_segment ? "Get #{resource}" : "Get All #{resource&.pluralize}"
      when 'POST' then "Create #{resource}"
      when 'PUT', 'PATCH' then "Update #{resource}"
      when 'DELETE' then "Delete #{resource}"
      else ''
      end
    end

    def swagger_response
      @swagger_response ||= ResponseBuilder.new(
        response,
        config: config,
        example_title: example_title
      ).build
    end

    def example_title
      full_rspec_description.presence || 'example-0'
    end

    def full_rspec_description
      config.with_rspec_examples ? self.class.rspec_description : nil
    end

    def controller_name
      request.params['controller'].to_s.split('/').last
    end

    def deep_dup(value)
      return value.deep_dup if value.respond_to?(:deep_dup)

      Marshal.load(Marshal.dump(value))
    end
  end
end

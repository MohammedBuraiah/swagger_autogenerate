# frozen_string_literal: true

module SwaggerAutogenerate
  # Builds OpenAPI parameters and requestBody from a Rails request.
  class ParameterBuilder
    def initialize(request, schema_builder: SchemaBuilder.new)
      @request = request
      @schema = schema_builder
      @payload_keys = []
      @payload_hash = {}
    end

    def parameters
      result = []
      push_individual(result, path_parameters, required: true)
      query_parameters.each { |name, value| push_complex(result, name.to_s, 'query', value) }
      push_individual(result, request_parameters) if request.request_parameters.blank?
      result
    end

    def request_body
      return if request.request_parameters.blank?

      { 'content' => json_to_content_form_data(request.request_parameters) }
    end

    def path_parameters
      { path: request.path_parameters.except(:controller, :format, :action) }
    end

    def query_parameters
      request.query_parameters
    end

    def request_parameters
      { body: request.request_parameters }
    end

    private

    attr_reader :request, :schema

    def push_complex(parameters, name, in_type, value, required: false)
      hash = {
        'name' => name.to_s,
        'in' => in_type.to_s,
        'schema' => schema.schema_data(value)
      }

      if in_type.to_s == 'query' && hash['schema']['type'] == 'object'
        hash['style'] = 'deepObject'
        hash['explode'] = true
      end

      hash['required'] = required if required
      parameters.push(hash)
    end

    def push_individual(parameters, parameter_set, required: false)
      return if parameter_set.blank?

      in_type = parameter_set.keys.first.to_s
      params_hash = parameter_set.values.first

      params_hash.each do |key, value|
        hash = {
          'name' => key.to_s,
          'in' => in_type,
          'schema' => schema.schema_data(value),
          'example' => schema.example(value)
        }

        hash['required'] = required if required
        hash.except!('example') if hash['example'].blank?
        parameters.push(hash)
      end
    end

    def json_to_content_form_data(json)
      {
        'multipart/form-data' => {
          'schema' => schema.build_properties(json)
        }
      }
    end
  end
end

# frozen_string_literal: true

module SwaggerAutogenerate
  # Merges a newly observed request/response into an existing OpenAPI document.
  class YamlMerger
    def initialize(yaml_file:, paths:, current_path:, request:, response:, swagger_response:,
                   example_title:, config:, schema_builder:, parameter_builder:, tags:, summary:, security:)
      @yaml_file = yaml_file
      @paths = paths
      @current_path = current_path
      @request = request
      @response = response
      @swagger_response = swagger_response
      @example_title = example_title
      @config = config
      @schema = schema_builder
      @parameter_builder = parameter_builder
      @tags = tags
      @summary = summary
      @security = security
    end

    def apply!
      check_path
      check_method
      check_status
      check_parameters
      check_parameter
      check_request_bodys
      check_request_body
      organize_result!(yaml_file['paths'])
      yaml_file
    end

    def organize_result!(current_paths)
      method = request.method.downcase
      return unless current_paths.dig(current_path, method)

      new_hash = {
        'tags' => tags,
        'summary' => summary
      }

      new_hash['parameters'] = current_paths[current_path][method]['parameters'] if current_paths.dig(current_path, method, 'parameters')
      new_hash['requestBody'] = current_paths[current_path][method]['requestBody'] if current_paths.dig(current_path, method, 'requestBody')
      new_hash['responses'] = current_paths[current_path][method]['responses']
      new_hash['security'] = security

      current_paths[current_path][method] = new_hash
    end

    def merge_example!(all_paths, with_schema_properties: false)
      method = request.method.downcase
      status = response.status.to_s
      old_examples = all_paths.dig(current_path, method, 'responses', status, 'content', 'application/json', 'examples')
      current_example = swagger_response.dig(status, 'content', 'application/json', 'examples', example_title)

      return true unless config.with_multiple_examples || old_examples&.keys&.count.to_i <= 1

      if !old_examples&.value?(current_example)
        last_example = resolve_example_name(old_examples)
        hash = { 'examples' => { last_example => current_example } }
        all_paths[current_path][method]['responses'][status]['content']['application/json'].deep_merge!(hash)
        add_properties_to_schema!(last_example, all_paths[current_path])
      elsif with_schema_properties
        add_properties_to_schema!(example_title, all_paths[current_path])
      end

      true
    end

    private

    attr_reader :yaml_file, :paths, :current_path, :request, :response, :swagger_response,
                :example_title, :config, :schema, :parameter_builder, :tags, :summary, :security

    def old_paths
      yaml_file['paths']
    end

    def method_key
      request.method.downcase
    end

    def check_path
      return if old_paths.key?(current_path)

      yaml_file['paths'].merge!({ current_path => paths[current_path] })
      update_example_title!(with_schema_properties: true)
    end

    def check_method
      return if old_paths[current_path].key?(method_key)

      yaml_file['paths'][current_path][method_key] = { 'responses' => swagger_response }
      update_example_title!(with_schema_properties: true)
    end

    def check_status
      responses = old_paths[current_path][method_key]['responses']

      if responses.present?
        if responses.key?(response.status.to_s)
          update_example_title!
        else
          responses.merge!(swagger_response)
          update_example_title!(with_schema_properties: true)
        end
      else
        yaml_file['paths'][current_path][method_key]['responses'] = swagger_response
        update_example_title!
      end
    end

    def check_parameters
      yaml_file['paths'][current_path][method_key]['parameters'] ||= []
    end

    def check_parameter
      current_params = paths.dig(current_path, method_key, 'parameters') || []
      existing_params_list = yaml_file['paths'][current_path][method_key]['parameters'] ||= []

      current_params.each do |param|
        existing_param = existing_params_list.find { |p| p['name'] == param['name'] && p['in'] == param['in'] }

        if existing_param
          merge_param_schemas!(existing_param, param)
        else
          existing_params_list.push(param)
        end
      end
    end

    def merge_param_schemas!(existing, new_param)
      return unless existing.dig('schema', 'type') == 'object' && new_param.dig('schema', 'type') == 'object'

      existing_props = existing.dig('schema', 'properties') || {}
      new_props = new_param.dig('schema', 'properties') || {}
      existing['schema']['properties'] = existing_props.merge(new_props)
    end

    def check_request_bodys
      new_body = paths.dig(current_path, method_key, 'requestBody')
      return if new_body.blank?
      return if old_paths[current_path][method_key]['requestBody'].present?

      yaml_file['paths'][current_path][method_key]['requestBody'] = new_body
    end

    def check_request_body
      new_props = paths.dig(current_path, method_key, 'requestBody', 'content', 'multipart/form-data', 'schema', 'properties')
      file_props = old_paths.dig(current_path, method_key, 'requestBody', 'content', 'multipart/form-data', 'schema', 'properties')
      return unless new_props.present? && file_props.present?

      (new_props.keys - file_props.keys).each do |param_name|
        file_props.merge!(new_props.slice(param_name))
      end
    end

    def update_example_title!(with_schema_properties: false)
      merge_example!(yaml_file['paths'], with_schema_properties: with_schema_properties)
    end

    def resolve_example_name(old_examples)
      last_example = example_title || old_examples&.keys&.last
      return last_example unless old_examples&.key?(last_example)

      Helpers.json_example_plus_one("#{last_example}-1")
    end

    def add_properties_to_schema!(last_example, main_path)
      return unless config.with_payload_properties

      parameters = {}
      parameters.merge!(
        parameter_builder.request_parameters.values.first || {},
        parameter_builder.query_parameters,
        parameter_builder.path_parameters.values.first || {}
      )

      hash = { last_example => schema.build_properties(parameters.as_json) }

      main_path[method_key]['responses'][response.status.to_s].deep_merge!(
        {
          'content' => {
            'application/json' => {
              'schema' => {
                'description' => 'These are the payloads for each example',
                'type' => 'object',
                'properties' => hash
              }
            }
          }
        }
      )
    end
  end
end

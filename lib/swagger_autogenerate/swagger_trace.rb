require_relative 'configuration'

module SwaggerAutogenerate
  class SwaggerTrace
    def initialize(request, response)
      @with_config = ::SwaggerAutogenerate.configuration.with_config
      @with_multiple_examples = ::SwaggerAutogenerate.configuration.with_multiple_examples
      @with_rspec_examples = ::SwaggerAutogenerate.configuration.with_rspec_examples
      @with_response_description = ::SwaggerAutogenerate.configuration.with_response_description
      @with_payload_properties = ::SwaggerAutogenerate.configuration.with_payload_properties
      @security = ::SwaggerAutogenerate.configuration.security
      @swagger_config = ::SwaggerAutogenerate.configuration.swagger_config
      @response_status = ::SwaggerAutogenerate.configuration.response_status
      @default_path = ::SwaggerAutogenerate.configuration.default_path
      @request = request
      @response = response
      @action_for_old_examples = ::SwaggerAutogenerate.configuration.action_for_old_examples
      @@paths = {}
    end

    def call
      read_swagger_trace
      write_swagger_trace
    end

    def self.swagger_path_environment_variable
      ::SwaggerAutogenerate.configuration.swagger_path_environment_variable
    end

    def swagger_path_environment_variable
      SwaggerTrace.swagger_path_environment_variable
    end

    def self.generate_swagger_environment_variable
      ::SwaggerAutogenerate.configuration.generate_swagger_environment_variable
    end

    def generate_swagger_environment_variable
      SwaggerTrace.generate_swagger_environment_variable
    end

    def self.environment_name
      ::SwaggerAutogenerate.configuration.environment_name
    end

    def environment_name
      SwaggerTrace.environment_name
    end

    private

    attr_reader :request, :response, :current_path, :yaml_file, :configuration,
                :with_config, :with_multiple_examples, :with_rspec_examples,
                :with_response_description, :with_payload_properties, :security, :response_status, :swagger_config,
                :default_path, :action_for_old_examples

    # main methods

    def read_swagger_trace
      path = request.path

      request.path_parameters.except(:controller, :format, :action).each do |k, v|
        path_array = path.split('/')
        index = path_array.rindex(v)
        path_array[index] = "{#{k}}"
        path.replace(path_array.join('/'))
      end

      @current_path = path
      method = request.method.to_s.downcase

      process_replacing_examples

      hash =
        {
          method => {
            'tags' => tags,
            'summary' => summary,
            'requestBody' => request_body,
            'parameters' => parameters,
            'responses' => {},
            'security' => current_security
          }
        }

      hash[method].except!('requestBody') if hash[method]['requestBody'].blank?
      paths[path.to_s] ||= {}
      paths[path.to_s].merge!(hash)
    end

    def write_swagger_trace
      if paths[current_path][request.method.downcase].present?
        paths[current_path][request.method.downcase]['responses'] = swagger_response
      end

      if File.exist?(swagger_location)
        edit_file
      else
        create_file
      end
    end

    def create_file
      File.open(swagger_location, 'w') do |file|
        return file.write(YAML.dump({ 'paths' => {} })) if paths.blank?
        data = with_config ? swagger_config : {}
        data['paths'] = paths
        organize_result(data['paths'])
        data = data.to_hash
        # handel examples names
        example_title = full_rspec_description.present? ? full_rspec_description : 'example-0'
        old_examples = data['paths'][current_path][request.method.downcase]['responses'][response.status.to_s]['content']['application/json']['examples']
        current_example = old_examples[example_title]
        new_example(example_title, current_example, old_examples, data['paths'], true)
        # result
        result = reformat_dates_in_hash(data)
        result = convert_to_hash(result)
        result = YAML.dump(result)
        file.write(result)
      end
    end

    def edit_file
      @yaml_file = \
        YAML.safe_load(
          File.read(swagger_location),
          aliases: true,
          permitted_classes: [Symbol, DateTime, Date, Time, ActiveSupport::HashWithIndifferentAccess],
          permitted_symbols: []
        )

      return create_file if yaml_file.nil? || yaml_file['paths'].nil?

      yaml_file.merge!(swagger_config) if with_config

      apply_yaml_file_changes
      organize_result(yaml_file['paths'])
      @yaml_file = convert_to_hash(yaml_file)
      File.open(swagger_location, 'w') do |file|
        result = reformat_dates_in_hash(yaml_file)
        result = convert_to_hash(result)
        result = YAML.dump(result)
        file.write(result)
      end
    end

    # Helpers

    def process_replacing_examples
      create_file_if_not_exist
      $removed_examples ||= []
      if action_for_old_examples == :replace && !$removed_examples.include?({ @current_path => request.method.to_s.downcase })
        current_yaml_file = YAML.load(
          File.read(swagger_location),
          aliases: true,
          permitted_classes: [Symbol, Date, ActiveSupport::HashWithIndifferentAccess]
        )

        hash = { "paths" => { @current_path => { request.method.to_s.downcase => {} } } }

        current_yaml_file&.merge!(hash)
        File.open(swagger_location, 'w') do |file|
          result = reformat_dates_in_hash(current_yaml_file)
          result = convert_to_hash(result)
          result = YAML.dump(result)
          file.write(result)
        end

        $removed_examples << { @current_path => request.method.to_s.downcase }
      end
    end

    def reformat_dates_in_hash(data)
      case data
      when Hash
        data.each do |key, value|
          data[key] = reformat_dates_in_hash(value)
        end
      when Array
        data.map! { |element| reformat_dates_in_hash(element) }
      when String
        if is_valid_date?(data)
          convert_to_date(data).to_s
        else
          data
        end
      else
        data
      end
    end

    def convert_to_hash(obj)
      case obj
      when ActiveSupport::HashWithIndifferentAccess
        obj.to_hash
      when Hash
        obj.transform_values { |value| convert_to_hash(value) }
      when Array
        obj.map { |item| convert_to_hash(item) }
      else
        obj
      end
    end

    def properties_data(value)
      hash = {}

      value.map do |k, v|
        type = schema_type(v)
        hash.merge!({ k => { 'type' => type, 'example' => convert_to_hash(v) } })
      end

      hash
    end

    def schema_data(value)
      type = schema_type(value)
      hash = { 'type' => type }

      if type == 'object'
        # FIX: Removed additionalProperties: true as requested
        hash['properties'] = (!value.nil? && value.present?) ? properties_data(value) : {}
      end

      hash
    end

    def schema_type(value)
      return 'integer' if number?(value)
      return 'boolean' if (value.try(:downcase) == 'true') || (value.try(:downcase) == 'false')
      return 'string' if value.instance_of?(String) || value.instance_of?(Symbol)
      return 'array' if value.instance_of?(Array)

      'object'
    end

    def set_complex_parameter(parameters, name, in_type, value, required: false)
      hash =
        {
          'name' => name.to_s,
          'in' => in_type.to_s,
          'schema' => schema_data(value)
        }

      if in_type.to_s == 'query' && hash['schema']['type'] == 'object'
        hash['style'] = 'deepObject'
        hash['explode'] = true
      end

      hash['required'] = required if required

      parameters.push(hash)
    end

    def set_individual_parameters(parameters, parameter_set, required: false)
      return if parameter_set.blank?

      in_type = parameter_set.keys.first.to_s
      params_hash = parameter_set.values.first

      params_hash.each do |key, value|
        hash =
          {
            'name' => key.to_s,
            'in' => in_type,
            'schema' => schema_data(value),
            'example' => example(value)
          }

        hash['required'] = required if required
        hash.except!('example') if hash['example'].blank?

        parameters.push(hash)
      end
    end

    def request_body
      content_body(request.request_parameters) if request.request_parameters.present?
    end

    def tags
      [yaml_file&.dig('paths', current_path, request.method.downcase, 'tags')&.last&.capitalize || ENV['tag'] || controller_name&.capitalize]
    end

    def summary
      yaml_file&.dig('paths', current_path, request.method.downcase, 'summary') || handel_summary(request.method.downcase, current_path)
    end

    def handel_summary(method, path)
      path_segments = path.split('/')
      resource = format_path_to_title(path)&.gsub('  ', ' ')
      id_segment = path.include?('{')

      case method.upcase
      when 'GET'
        id_segment ? "Get #{resource}" : "Get All #{resource&.pluralize}"
      when 'POST'
        "Create #{resource}"
      when 'PUT'
        "Update #{resource}"
      when 'DELETE'
        "Delete #{resource}"
      else
        ""
      end
    end

    def format_path_to_title(path)
      cleaned_path = path.sub(%r{^/v\d+/}, '')
      cleaned_path.gsub!(/\{[^}]+\}/, '')
      title = cleaned_path.split('/').map(&:capitalize).join(' ')
      title
    end

    def current_security
      yaml_file&.dig('paths', current_path, request.method.downcase, 'security') || security
    end

    def response_description
      response_status[response.status]
    end

    def swagger_response
      hash = {}
      begin
        swagger_response = JSON.parse(response.body)
      rescue JSON::ParserError
        swagger_response = { 'file' => 'file/data' }
      end

      hash['description'] = response_description if with_response_description
      hash['headers'] = {} # response.headers
      hash['content'] = content_json_example(swagger_response)

      {
        response.status.to_s => hash
      }
    end

    def convert_to_multipart(payload, main_key = nil, index = nil)
      payload_keys.push(main_key) if main_key.present?
      payload.each do |key, value|
        if value.is_a?(Hash)
          payload_keys.push(key)
          convert_to_multipart(value)
        elsif value.is_a?(Array)
          value.each_with_index { |v, index| convert_to_multipart(v, key, index) }
        else
          keys = payload_keys.clone
          first_key = keys.shift
          if index.present?
            keys.each { |inner_key| first_key = "#{first_key}[#{inner_key}][#{index}]" }
          else
            keys.each { |inner_key| first_key = "#{first_key}[#{inner_key}]" }
          end

          first_key = "#{first_key}[#{key}]"
          payload_hash.merge!({ first_key => { 'type' => schema_type(value), 'example' => example(value) } })
        end
      end
    end

    def content_form_data(data)
      hash_data = {}
      data.map do |key, value|
        if value.is_a?(Hash)
          hash_data.merge!({ key => value })
        elsif value.is_a?(Array)
          value.each_with_index { |v, index| convert_to_multipart(v, key) }
        else
          payload_hash.merge!({ key => { 'type' => schema_type(value), 'example' => example(value) } })
        end
      end

      convert_to_multipart(hash_data)
      converted_payload = @payload_hash.clone
      @payload_hash = nil
      @payload_keys = nil

      {
        'multipart/form-data' => {
          'schema' => {
            'type' => 'object',
            'properties' => converted_payload
          }
        }
      }
    end

    def json_to_content_form_data(json)
      {
        'multipart/form-data' => {
          'schema' => build_properties(json)
        }
      }
    end

    def build_properties(json)
      case json
      when Hash
        hash_properties = json.transform_values { |value| build_properties(value) if value.present? }
        hash_properties = hash_properties.delete_if { |_k, v| !v.present? }

        hashs = {
          'type' => 'object',
          'properties' => hash_properties
        }
      when Array
        item_schemas = json.map { |item| build_properties(item) }
        merged_schema = merge_array_schemas(item_schemas)

        if merged_schema[:type] == 'object'
          { 'type' => 'array', 'items' => merged_schema }
        else
          { 'type' => 'array', 'items' => { 'oneOf' => item_schemas.uniq } }
        end
      when String
        if integer?(json)
          { 'type' => 'integer', 'example' => json.to_i }
        elsif number?(json)
          { 'type' => 'number', 'example' => json.to_f }
        elsif is_valid_date?(json)
          { 'type' => 'string', 'example' => json.to_date.to_s }
        else
          { 'type' => 'string', 'example' => json.to_s }
        end
      when Integer
        { 'type' => 'integer', 'example' => json }
      when Float
        { 'type' => 'number', 'example' => json }
      when TrueClass, FalseClass
        { 'type' => 'boolean', 'example' => json }
      when Date, Time, DateTime
        { 'type' => 'string', 'example' => json.to_date.to_s }
      else
        { 'type' => 'string', 'example' => json.to_s }
      end
    end

    def merge_array_schemas(schemas)
      return {} if schemas.empty?
      schemas.reduce do |merged, schema|
        merge_properties(merged, schema)
      end
    end

    def merge_properties(old_data, new_data)
      return old_data unless old_data.is_a?(Hash) && new_data.is_a?(Hash)

      merged = old_data.dup
      new_data.each do |key, value|
        merged[key] = if merged[key].is_a?(Hash) && value.is_a?(Hash)
                        merge_properties(merged[key], value)
                      else
                        value
                      end
      end
      merged
    end

    def content_application_json_schema_properties(data)
      hash_data = {}
      data.map do |key, value|
        if value.is_a?(Hash)
          hash_data.merge!({ key => value })
        elsif value.is_a?(Array)
          value.each_with_index { |v, index| convert_to_multipart(v, key, index) }
        else
          payload_hash.merge!({ key => { 'type' => schema_type(value), 'example' => example(value) } })
        end
      end

      convert_to_multipart(hash_data)
      converted_payload = @payload_hash.clone
      @payload_hash = nil
      @payload_keys = nil

      converted_payload
    end

    def content_body(data)
      hash = {}
      hash.merge!(json_to_content_form_data(data))
      { 'content' => hash }
    end

    def number?(value)
      true if Float(value)
    rescue StandardError
      false
    end

    def integer?(value)
      true if Integer(value)
    rescue StandardError
      false
    end

    def example(value)
      return value.to_i if number?(value)
      return convert_to_date(value) if value.instance_of?(String) && is_valid_date?(value)
      return value if value.instance_of?(String) || value.instance_of?(Symbol)

      nil
    end

    def is_valid_date?(string)
      Date.strptime(string)
      true
    rescue ArgumentError
      false
    end

    def convert_to_date(string)
      datetime = Date.strptime(string)
      return Date.parse(string).strftime('%Y/%m/%d') if datetime.year == 1
      datetime.strftime('%Y/%m/%d')
    rescue ArgumentError
      string
    end

    # parameters

    def parameters
      parameters = []

      # 1. Path Parameters
      set_individual_parameters(parameters, path_parameters, required: true)

      # 2. Query Parameters
      query_parameters.each do |name, value|
        set_complex_parameter(parameters, name.to_s, 'query', value)
      end

      # 3. Request Parameters
      set_individual_parameters(parameters, request_parameters) if request.request_parameters.blank?

      parameters
    end

    def request_parameters
      { body: request.request_parameters }
    end

    def query_parameters
      request.query_parameters
    end

    def path_parameters
      { path: request.path_parameters.except(:controller, :format, :action) }
    end

    # Static

    def paths
      @@paths ||= {}
    end

    def controller_name
      request.params['controller'].split('/').last.to_s
    end

    def swagger_location
      return @swagger_location if instance_variable_defined?(:@swagger_location)

      if ENV[generate_swagger_environment_variable].present?
        directory_path = Rails.root.join(default_path).to_s
        FileUtils.mkdir_p(directory_path) unless File.directory?(directory_path)
        @swagger_location = "#{directory_path}/#{snake_case(tags&.first)}.yaml"
      elsif ENV[swagger_path_environment_variable].include?('.yaml') || ENV[swagger_path_environment_variable].include?('.yml')
        @swagger_location = Rails.root.join(ENV.fetch(swagger_path_environment_variable, nil).to_s).to_s
      else
        directory_path = Rails.root.join(ENV.fetch(swagger_path_environment_variable, nil).to_s).to_s
        FileUtils.mkdir_p(directory_path) unless File.directory?(directory_path)
        @swagger_location = "#{directory_path}/#{snake_case(tags&.first)}.yaml"
      end
    end

    def content_json(data)
      {
        'application/json' => {
          'schema' => { 'type' => 'object' },
          'example' => data
        }
      }
    end

    def content_json_example(data)
      example_title = full_rspec_description.present? ? full_rspec_description : 'example-0'

      {
        'application/json' => {
          'schema' => { 'type' => 'object' },
          'examples' => {
            example_title => {
              'value' => data
            }
          }
        }
      }
    end

    def example_description
      body_ = request_parameters.values.first.present? ? { 'body_params' => request_parameters.values.first&.as_json }: nil
      query_ = query_parameters.present? ? { 'query_params' => query_parameters&.as_json } : nil
      path_ = path_parameters.values.first.present? ? { 'path_params' => path_parameters.values.first&.as_json }: nil

      [path_, query_, body_].
        compact.
        to_s.
        gsub('-', '/').
        gsub("'", '').
        gsub("=>", ': ')
    end

    def json_example_plus_one(string)
      if string =~ /(\d+)$/
        modified_numeric_part = $1.to_i + 1
        string.sub(/(\d+)$/, modified_numeric_part.to_s)
      else
        string
      end
    end

    def payload_keys
      @payload_keys ||= []
    end

    def payload_hash
      @payload_hash ||= {}
    end

    def new_example(example_title, current_example, old_examples, all_paths = yaml_file['paths'], with_schema_properties = false)
      if with_multiple_examples || old_examples&.keys&.count.to_i <= 1
        if !old_examples&.value?(current_example)
          last_example = handel_name_last_example(old_examples)
          last_example ||= example_title
          last_example = example_title
          hash = { 'examples' => { last_example => current_example } }
          all_paths[current_path][request.method.downcase]['responses'][response.status.to_s]['content']['application/json'].deep_merge!(hash)
          add_properties_to_schema(last_example, all_paths[current_path])
        elsif with_schema_properties
          add_properties_to_schema(full_rspec_description.present? ? full_rspec_description : 'example-0', all_paths[current_path])
        end
      end

      true
    end

    def handel_name_last_example(old_examples)
      last_example = full_rspec_description || old_examples.keys.last
      if old_examples&.keys&.include?(last_example)
        last_example += '-1'
        json_example_plus_one(last_example)
      end
    end

    def add_properties_to_schema(last_example, main_path = yaml_file['paths'][current_path])
      if with_payload_properties
        parameters = {}
        parameters.merge!(request_parameters.values.first, query_parameters, path_parameters.values.first)
        hash = {
          last_example => build_properties(parameters.as_json)
        }

        main_path[request.method.downcase]['responses'][response.status.to_s].deep_merge!(
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

    # FIX: Run check_parameters and check_parameter sequentially so explicit logic runs
    def apply_yaml_file_changes
      check_path
      check_method
      check_status
      check_parameters
      check_parameter
      check_request_bodys
      check_request_body
    end

    def old_paths
      yaml_file['paths']
    end

    # checks

    def organize_result(current_paths)
      if current_paths.dig(current_path, request.method.downcase).present?
        new_hash = {
          'tags' => tags,
          'summary' => summary
        }

        new_hash['parameters'] = current_paths[current_path][request.method.downcase]['parameters'] if current_paths.dig(current_path, request.method.downcase, 'parameters')
        new_hash['requestBody'] = current_paths[current_path][request.method.downcase]['requestBody'] if current_paths.dig(current_path, request.method.downcase, 'requestBody')
        new_hash['responses'] = current_paths[current_path][request.method.downcase]['responses']
        new_hash['security'] = current_security

        current_paths[current_path][request.method.downcase] = new_hash
      end
    end

    def check_path
      unless old_paths.key?(current_path)
        yaml_file['paths'].merge!({ current_path => paths[current_path] })
        update_example_title(true)
      end
    end

    def check_method
      unless old_paths[current_path].key?(request.method.downcase)
        yaml_file['paths'][current_path][request.method.downcase] = { 'responses' => swagger_response }
        update_example_title(true)
      end
    end

    def check_status
      example_title = full_rspec_description.present? ? full_rspec_description : 'example-0'
      if old_paths[current_path][request.method.downcase]['responses'].present?
        if old_paths[current_path][request.method.downcase]['responses']&.key?(response.status.to_s)
          update_example_title
        else
          yaml_file['paths'][current_path][request.method.downcase]['responses'].merge!(swagger_response)
          update_example_title(true)
        end
      else
        yaml_file['paths'][current_path][request.method.downcase]['responses'] = swagger_response
        update_example_title
      end
    end

    # FIX: Stop overwriting parameters. Only initialize if missing.
    def check_parameters
      if old_paths[current_path][request.method.downcase]['parameters'].nil?
        yaml_file['paths'][current_path][request.method.downcase]['parameters'] = []
      end
    end

    # FIX: Merge logic for schemas
    def check_parameter
      current_params = paths[current_path][request.method.downcase]['parameters'] || []

      # Ensure existing parameters list exists
      yaml_file['paths'][current_path][request.method.downcase]['parameters'] ||= []
      existing_params_list = yaml_file['paths'][current_path][request.method.downcase]['parameters']

      current_params.each do |param|
        # Check if parameter with same name AND 'in' location exists
        existing_param = existing_params_list.find { |p| p['name'] == param['name'] && p['in'] == param['in'] }

        if existing_param
          # If it exists, merge the schemas (accumulate properties)
          merge_param_schemas(existing_param, param)
        else
          # If it is new, just add it
          existing_params_list.push(param)
        end
      end
    end

    # Helper method to merge schema properties of object parameters
    def merge_param_schemas(existing, new_param)
      # We only merge if both are objects and have schemas
      if existing.dig('schema', 'type') == 'object' && new_param.dig('schema', 'type') == 'object'
        existing_props = existing.dig('schema', 'properties') || {}
        new_props = new_param.dig('schema', 'properties') || {}

        # Merge new properties into existing ones (Accumulate keys)
        existing['schema']['properties'] = existing_props.merge(new_props)
      end
    end

    def check_request_bodys
      if paths[current_path][request.method.downcase]['requestBody'].present? && old_paths[current_path][request.method.downcase]['requestBody'].nil?
        yaml_file['paths'][current_path][request.method.downcase]['requestBody'] = paths[current_path][request.method.downcase]['requestBody']
      end
    end

    def check_request_body
      if paths[current_path][request.method.downcase]['requestBody'].present?
        param_current_hash = paths[current_path][request.method.downcase]['requestBody']['content']['multipart/form-data']['schema']['properties']
        param_current_file = yaml_file['paths'][current_path][request.method.downcase]['requestBody']['content']['multipart/form-data']['schema']['properties']
        if param_current_hash.present? && param_current_file.present?
          param_names = param_current_hash.keys - param_current_file.keys
          param_names.each do |param_name|
            param = paths[current_path][request.method.downcase]['requestBody']['content']['multipart/form-data']['schema']['properties'].select { |parameter| parameter == param_name }
            yaml_file['paths'][current_path][request.method.downcase]['requestBody']['content']['multipart/form-data']['schema']['properties'].merge!(param)
          end
        end
      end
    end

    def update_example_title(with_schema_properties = false)
      example_title = full_rspec_description.present? ? full_rspec_description : 'example-0'
      current_example = swagger_response[response.status.to_s]['content']['application/json']['examples'][example_title]
      old_examples = old_paths[current_path][request.method.downcase]['responses'][response.status.to_s]['content']['application/json']['examples']
      new_example(example_title, current_example, old_examples, yaml_file['paths'], with_schema_properties)
    end

    def full_rspec_description
      with_rspec_examples ? SwaggerAutogenerate::SwaggerTrace.rspec_description : nil
    end

    def create_file_if_not_exist
      create_file unless File.exist?(swagger_location)
    end

    def snake_case(text)
      return text&.downcase if text&.match?(/\A[A-Z]+\z/)

      text
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z])([A-Z])/, '\1_\2')
        .downcase
        .tr(' ', '_')
    end

    class << self
      attr_accessor :rspec_description
    end
  end
end

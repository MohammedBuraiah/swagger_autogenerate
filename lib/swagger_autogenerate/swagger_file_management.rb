module SwaggerAutogenerate
  module SwaggerFileManagement
    def read_swaggger_trace
      path = request.path

      request.path_parameters.except(:controller, :format, :action).each do |k, v|
        path = path.gsub!(v, "{#{k}}")
      end

      @current_path = path
      method = request.method.to_s.downcase
      hash =
        {
          method => {
            'tags' => tags,
            'summary' => summary,
            'requestBody' => request_body,
            'parameters' => parameters,
            'responses' => {},
            'security' => security
          }
        }

      hash[method].except!('requestBody') if hash[method]['requestBody'].blank?
      paths[path.to_s] ||= {}
      paths[path.to_s].merge!(hash)
    end

    def write_swaggger_trace
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
        data = WITH_CONFIG ? swagger_config : {}
        data['paths'] = paths
        organize_result(data['paths'])
        data = data.to_hash
        result = add_quotes_to_dates(YAML.dump(data))
        file.write(result)
      end
    end

    def edit_file
      @yaml_file = YAML.load(
        File.read(swagger_location),
        aliases: true,
        permitted_classes: [Symbol, Date, ActiveSupport::HashWithIndifferentAccess]
      )

      return create_file if yaml_file.nil? || yaml_file['paths'].nil?

      yaml_file.merge!(swagger_config) if WITH_CONFIG

      apply_yaml_file_changes
      organize_result(yaml_file['paths'])
      @yaml_file = convert_to_hash(yaml_file)
      File.open(swagger_location, 'w') do |file|
        result = add_quotes_to_dates(YAML.dump(yaml_file))
        file.write(result)
      end
    end

    def apply_yaml_file_changes
      (check_path || check_method || check_status) &&
        (check_parameters || check_parameter) &&
        (check_request_bodys || check_request_body)
    end
  end
end

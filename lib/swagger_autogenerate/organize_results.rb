module SwaggerAutogenerate
  module OrganizeResults
    def organize_result(current_paths)
      new_hash = {
        'tags' => tags,
        'summary' => summary
      }
      new_hash['parameters'] = current_paths[current_path][request.method.downcase]['parameters'] if current_paths[current_path][request.method.downcase]['parameters']
      new_hash['requestBody'] = current_paths[current_path][request.method.downcase]['requestBody'] if current_paths[current_path][request.method.downcase]['requestBody']
      new_hash['responses'] = current_paths[current_path][request.method.downcase]['responses']
      new_hash['security'] = security

      current_paths[current_path][request.method.downcase] = new_hash
    end

    def check_path
      unless old_paths.key?(current_path)
        yaml_file['paths'].merge!({ current_path => paths[current_path] })
      end
    end

    def check_method
      unless old_paths[current_path].key?(request.method.downcase)
        yaml_file['paths'][current_path][request.method.downcase] = { 'responses' => swagger_response }
      end
    end

    def check_status
      if old_paths[current_path][request.method.downcase]['responses'].present?
        if old_paths[current_path][request.method.downcase]['responses']&.key?(response.status.to_s)
          new_example
        else
          yaml_file['paths'][current_path][request.method.downcase]['responses'].merge!(swagger_response)
        end
      else
        yaml_file['paths'][current_path][request.method.downcase]['responses'] = swagger_response
      end
    end

    def check_parameters
      if old_paths[current_path][request.method.downcase]['parameters'].blank?
        yaml_file['paths'][current_path][request.method.downcase]['parameters'] = paths[current_path][request.method.downcase]['parameters']
      end
    end

    def check_parameter
      param_names = paths[current_path][request.method.downcase]['parameters'].pluck('name') - yaml_file['paths'][current_path][request.method.downcase]['parameters'].pluck('name')
      param_names.each do |param_name|
        param = paths[current_path][request.method.downcase]['parameters'].find { |parameter| parameter['name'] == param_name }
        yaml_file['paths'][current_path][request.method.downcase]['parameters'].push(param)
      end
    end

    def check_request_bodys
      if paths[current_path][request.method.downcase]['requestBody'].present? && old_paths[current_path][request.method.downcase]['requestBody'].nil?
        yaml_file['paths'][current_path][request.method.downcase]['requestBody'] = paths[current_path][request.method.downcase]['requestBody']
      end
    end

    def check_request_body
      if paths[current_path][request.method.downcase]['requestBody'].present?
        param_names = paths[current_path][request.method.downcase]['requestBody']['content']['multipart/form-data']['schema']['properties'].keys - yaml_file['paths'][current_path][request.method.downcase]['requestBody']['content']['multipart/form-data']['schema']['properties'].keys
        param_names.each do |param_name|
          param = paths[current_path][request.method.downcase]['requestBody']['content']['multipart/form-data']['schema']['properties'].select { |parameter| parameter == param_name }
          yaml_file['paths'][current_path][request.method.downcase]['requestBody']['content']['multipart/form-data']['schema']['properties'].merge!(param)
        end
      end
    end
  end
end

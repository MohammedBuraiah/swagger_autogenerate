module SwaggerAutogenerate
  module JsonHandling
    def content_json(data)
      {
        'application/json' => {
          'schema' => { 'type' => 'object' },
          'example' => data
        }
      }
    end

    def content_json_example(data)
      hash = {
        'application/json' => {
          'schema' => { 'type' => 'object' },
          'examples' => {
            'example-0' => {
              'value' => data
            }
          }
        }
      }
      hash['application/json']['examples']['example-0']['description'] = "payload => #{example_description}" if WITH_EXAMPLE_DESCRIPTION && !example_description.empty?

      hash
    end

    def json_example_plus_one(string)
      if string =~ /(\d+)$/
        modified_numeric_part = $1.to_i + 1
        string.sub(/(\d+)$/, modified_numeric_part.to_s)
      else
        string
      end
    end

    def example_description
      body_ = request_parameters.values.first.present? ? { 'body_params' => request_parameters.values.first&.as_json }: nil
      query_ = query_parameters.values.first.present? ? { 'query_params' => query_parameters.values.first&.as_json } : nil
      path_ = path_parameters.values.first.present? ? { 'path_params' => path_parameters.values.first&.as_json }: nil

      [path_, query_, body_].
        compact.
        to_s.
        gsub('-', '/').
        gsub("'", '').
        gsub("=>", ': ')
    end

    def payload_keys
      @payload_keys ||= []
    end

    def payload_hash
      @payload_hash ||= {}
    end

    def new_example
      current_example = swagger_response[response.status.to_s]['content']['application/json']['examples']['example-0']
      old_examples = old_paths[current_path][request.method.downcase]['responses'][response.status.to_s]['content']['application/json']['examples']

      unless old_examples.value?(current_example)
        last_example = json_example_plus_one(old_examples.keys.last)
        last_example ||= 'example-0'
        last_example = 'example-0' unless WITH_MULTIPLE_EXAMPLES
        yaml_file['paths'][current_path][request.method.downcase]['responses'][response.status.to_s]['content']['application/json']['examples'][last_example] = current_example
      end

      true
    end

    def old_paths
      yaml_file['paths']
    end
  end
end

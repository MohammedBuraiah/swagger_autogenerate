module SwaggerAutogenerate
  module SwaggerDataExtraction
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
      hash['properties'] = {}
      hash['properties'] = properties_data(value) if type == 'object' && !value.nil?

      hash
    end

    def set_parameters(parameters, parameter, required: false)
      return if parameter.blank?

      parameter.values.first.each do |key, value|
        hash =
          {
            'name' => key.to_s,
            'in' => parameter.keys.first.to_s,
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
      [ENV['tag'] || controller_name]
    end

    def summary
      URI.parse(request.path).path
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

      hash['description'] = response_description if WITH_RESPONSE_DESCRIPTION
      hash['headers'] = {} # response.headers
      hash['content'] = content_json_example(swagger_response)

      {
        response.status.to_s => hash
      }
    end

    def convert_to_multipart(payload)
      payload.each do |key, value|
        if value.is_a?(Hash)
          payload_keys.push(key)
          convert_to_multipart(value)
        else
          keys = payload_keys.clone
          first_key = keys.shift
          keys.each { |inner_key| first_key = "#{first_key}[#{inner_key}]" }
          first_key = "#{first_key}[#{key}]"

          payload_hash.merge!({ first_key => { 'type' => schema_type(value), 'example' => example(value) } })
        end
      end
    end

    def content_form_data(data)
      convert_to_multipart(data)
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

    def content_body(data)
      hash = {}
      # hash.merge!(content_json(data))
      hash.merge!(content_form_data(data))

      { 'content' => hash }
    end
  end
end

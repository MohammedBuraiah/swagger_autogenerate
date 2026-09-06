# frozen_string_literal: true

module SwaggerAutogenerate
  # Builds OpenAPI response objects from a Rails response.
  class ResponseBuilder
    def initialize(response, config:, example_title:)
      @response = response
      @config = config
      @example_title = example_title
    end

    def build
      body =
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError
          { 'file' => 'file/data' }
        end

      hash = {
        'headers' => {},
        'content' => content_json_example(body)
      }
      hash['description'] = config.response_status[response.status] if config.with_response_description

      { response.status.to_s => hash }
    end

    private

    attr_reader :response, :config, :example_title

    def content_json_example(data)
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
  end
end

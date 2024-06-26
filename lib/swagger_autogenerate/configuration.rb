module SwaggerAutogenerate
  class Configuration
    attr_accessor :with_config, :with_multiple_examples, :with_example_description,
                  :with_response_description, :swagger_environment_variable,
                  :environment_name, :security, :swagger_config, :response_status

    def initialize
      @with_config = true
      @with_multiple_examples = true
      @with_example_description = true
      @with_response_description = true
      @swagger_environment_variable = 'SWAGGER'
      @environment_name = :test
      @security = default_security
      @swagger_config = default_swagger_config
      @response_status = default_response_status
    end

    def default_response_status
      {
        100 => 'The initial part of the request has been received, and the client should proceed with sending the remainder of the request',
        101 => 'The server agrees to switch protocols and is acknowledging the client\'s request to change the protocol being used',
        200 => 'The request has succeeded',
        201 => 'The request has been fulfilled, and a new resource has been created as a result. The newly created resource is returned in the response body',
        202 => 'The request has been accepted for processing, but the processing has not been completed. The response may contain an estimated completion time or other status information',
        204 => 'The server has successfully processed the request but does not need to return any content. It is often used for requests that don\'t require a response body, such as DELETE requests',
        300 => 'The requested resource has multiple choices available, each with its own URI and representation. The client can select one of the available choices',
        301 => 'The requested resource has been permanently moved to a new location, and any future references to this resource should use the new URI provided in the response',
        302 => 'The requested resource has been temporarily moved to a different location. The client should use the URI specified in the response for future requests',
        304 => 'The client\'s cached copy of a resource is still valid, and there is no need to transfer a new copy. The client can use its cached version',
        400 => 'The server cannot understand the request due to a client error, such as malformed syntax or invalid parameters',
        401 => 'The request requires user authentication. The client must provide valid credentials (e.g., username and password) to access the requested resource',
        403 => 'The server understood the request, but the client does not have permission to access the requested resource',
        404 => 'The requested resource could not be found on the server',
        405 => 'The requested resource does not support the HTTP method used in the request (e.g., GET, POST, PUT, DELETE)',
        409 => 'The request could not be completed due to a conflict with the current state of the target resource. The client may need to resolve the conflict before resubmitting the request',
        422 => 'The server understands the content type of the request entity but was unable to process the contained instructions',
        500 => 'The server encountered an unexpected condition that prevented it from fulfilling the request',
        502 => 'The server acting as a gateway or proxy received an invalid response from an upstream server',
        503 => 'The server is currently unable to handle the request due to temporary overload or maintenance. The server may provide a Retry-After header to indicate when the client can try the request again',
        504 => 'The server acting as a gateway or proxy did not receive a timely response from an upstream server'
      }
    end

    def default_swagger_config
      {
        'openapi' => '3.0.0',
        'info' => {
          'title' => 'title',
          'description' => 'description',
          'version' => '1.0.0'
        },
        'servers' => [],
        'components' => {
          'securitySchemes' => {
            'locale' => {
              'type' => 'apiKey',
              'in' => 'query',
              'name' => 'locale'
            }
          }
        }
      }
    end

    def default_security
      [
        { 'org_slug' => [] },
        { 'locale' => [] }
      ]
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end

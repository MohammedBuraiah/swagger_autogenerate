module SwaggerAutogenerate
  class Configuration
    attr_accessor :with_config, :with_multiple_examples, :with_example_description,
                  :with_response_description, :swagger_environment_variable

    def initialize
      @with_config = true
      @with_multiple_examples = true
      @with_example_description = true
      @with_response_description = true
      @swagger_environment_variable = 'SWAGGER'
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end

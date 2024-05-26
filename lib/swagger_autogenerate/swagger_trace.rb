require_relative 'swagger_public_methods'

module SwaggerAutogenerate
  class SwaggerTrace
    WITH_CONFIG = true
    WITH_MULTIPLE_EXAMPLES = true
    WITH_EXAMPLE_DESCRIPTION = true
    WITH_RESPONSE_DESCRIPTION = true
    SWAGGER_ENVIRONMENT_VARIABLE = 'SWAGGER'

    include SwaggerPublicMethods
    include JsonHandling
    include OrganizeResults
    include ParameterHandling
    include PathsSecurity
    include SwaggerDataExtraction
    include UtilityMethods
    include YamlFileHandling
    include SwaggerFileManagement

    def initialize(request, response)
      @request = request
      @response = response
      @@paths = {}
    end

    def call
      if ENV[SWAGGER_ENVIRONMENT_VARIABLE].present?
        read_swaggger_trace
        write_swaggger_trace
      end
    end

    private

    attr_reader :request, :response, :current_path, :yaml_file
  end
end

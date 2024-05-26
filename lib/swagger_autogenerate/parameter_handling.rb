module SwaggerAutogenerate
  module ParameterHandling
    def parameters
      parameters = []

      set_parameters(parameters, path_parameters, required: true)
      set_parameters(parameters, request_parameters) if request.request_parameters.blank?
      set_parameters(parameters, query_parameters)

      parameters
    end

    def request_parameters
      { body: request.request_parameters }
    end

    def query_parameters
      { query: request.query_parameters }
    end

    def path_parameters
      { path: request.path_parameters.except(:controller, :format, :action) }
    end
  end
end

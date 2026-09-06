# frozen_string_literal: true

module SwaggerAutogenerate
  # Turns concrete request paths into OpenAPI path templates.
  # Example: /users/42 -> /users/{id}
  class PathNormalizer
    def self.call(request)
      path = request.path.dup

      request.path_parameters.except(:controller, :format, :action).each do |key, value|
        path_array = path.split('/')
        index = path_array.rindex(value.to_s)
        next unless index

        path_array[index] = "{#{key}}"
        path = path_array.join('/')
      end

      path
    end
  end
end

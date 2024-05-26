module SwaggerAutogenerate
  module PathsSecurity
    def paths
      @@paths ||= {}
    end

    def security
      [
        'org_slug' => [],
        'locale' => []
      ]
    end

    def controller_name
      request.params['controller'].split('/').last.to_s
    end

    def swagger_location
      return @swagger_location if instance_variable_defined?(:@swagger_location)

      if ENV[SWAGGER_ENVIRONMENT_VARIABLE].include?('.yaml') || ENV[SWAGGER_ENVIRONMENT_VARIABLE].include?('.yml')
        @swagger_location = Rails.root.join(ENV.fetch(SWAGGER_ENVIRONMENT_VARIABLE, nil).to_s).to_s
      else
        directory_path = Rails.root.join(ENV.fetch(SWAGGER_ENVIRONMENT_VARIABLE, nil).to_s).to_s
        FileUtils.mkdir_p(directory_path) unless File.directory?(directory_path)
        @swagger_location = "#{directory_path}/#{tags.first}.yaml"
      end
    end
  end
end

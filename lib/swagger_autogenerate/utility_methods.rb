module SwaggerAutogenerate
  module UtilityMethods
    def number?(value)
      true if Float(value)
    rescue StandardError
      false
    end

    def schema_type(value)
      return 'integer' if number?(value)
      return 'boolean' if (value.try(:downcase) == 'true') || (value.try(:downcase) == 'false')
      return 'string' if value.instance_of?(String) || value.instance_of?(Symbol)
      return 'array' if value.instance_of?(Array)

      'object'
    end

    def example(value)
      return value.to_i if number?(value)
      return convert_to_date(value) if value.instance_of?(String) && is_valid_date?(value)
      return value if value.instance_of?(String) || value.instance_of?(Symbol)

      nil
    end

    def is_valid_date?(string)
      Date.parse(string)
      true
    rescue ArgumentError
      false
    end

    def convert_to_date(string)
      datetime = DateTime.parse(string)
      datetime.strftime('%Y-%m-%d')
    rescue ArgumentError
      string
    end
  end
end

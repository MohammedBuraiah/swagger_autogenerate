module SwaggerAutogenerate
  module YamlFileHandling
    def convert_to_hash(obj)
      case obj
      when ActiveSupport::HashWithIndifferentAccess
        obj.to_hash
      when Hash
        obj.transform_values { |value| convert_to_hash(value) }
      when Array
        obj.map { |item| convert_to_hash(item) }
      else
        obj
      end
    end

    def add_quotes_to_dates(string)
      string = remove_quotes_in_dates(string)
      string.gsub(/\b\d{4}-\d{2}-\d{2}\b/, "'\\0'")
    end

    def remove_quotes_in_dates(string)
      string.gsub(/'(\d{4}-\d{2}-\d{2})'/, '\1')
    end
  end
end

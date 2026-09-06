# frozen_string_literal: true

module SwaggerAutogenerate
  # Infers OpenAPI schema fragments from Ruby values.
  class SchemaBuilder
    def schema_type(value)
      return 'integer' if Helpers.number?(value)
      return 'boolean' if value.to_s.downcase == 'true' || value.to_s.downcase == 'false'
      return 'string' if value.is_a?(String) || value.is_a?(Symbol)
      return 'array' if value.is_a?(Array)

      'object'
    end

    def example(value)
      return value.to_i if Helpers.number?(value)
      return Helpers.convert_to_date(value) if value.is_a?(String) && Helpers.valid_date?(value)
      return value if value.is_a?(String) || value.is_a?(Symbol)

      nil
    end

    def properties_data(value)
      value.each_with_object({}) do |(key, val), hash|
        hash[key] = { 'type' => schema_type(val), 'example' => Helpers.convert_to_hash(val) }
      end
    end

    def schema_data(value)
      type = schema_type(value)
      hash = { 'type' => type }
      hash['properties'] = value.present? ? properties_data(value) : {} if type == 'object'
      hash
    end

    def build_properties(json)
      case json
      when Hash
        hash_properties = json.transform_values { |value| build_properties(value) if value.present? }
        hash_properties = hash_properties.delete_if { |_k, v| v.blank? }

        {
          'type' => 'object',
          'properties' => hash_properties
        }
      when Array
        item_schemas = json.map { |item| build_properties(item) }
        merged_schema = merge_array_schemas(item_schemas)

        if merged_schema[:type] == 'object' || merged_schema['type'] == 'object'
          { 'type' => 'array', 'items' => merged_schema }
        else
          { 'type' => 'array', 'items' => { 'oneOf' => item_schemas.uniq } }
        end
      when String
        if Helpers.integer?(json)
          { 'type' => 'integer', 'example' => json.to_i }
        elsif Helpers.number?(json)
          { 'type' => 'number', 'example' => json.to_f }
        elsif Helpers.valid_date?(json)
          { 'type' => 'string', 'example' => json.to_date.to_s }
        else
          { 'type' => 'string', 'example' => json.to_s }
        end
      when Integer
        { 'type' => 'integer', 'example' => json }
      when Float
        { 'type' => 'number', 'example' => json }
      when TrueClass, FalseClass
        { 'type' => 'boolean', 'example' => json }
      when Date, Time, DateTime
        { 'type' => 'string', 'example' => json.to_date.to_s }
      else
        { 'type' => 'string', 'example' => json.to_s }
      end
    end

    private

    def merge_array_schemas(schemas)
      return {} if schemas.empty?

      schemas.reduce { |merged, schema| Helpers.merge_properties(merged, schema) }
    end
  end
end

# frozen_string_literal: true

module SwaggerAutogenerate
  module Helpers
    module_function

    def number?(value)
      Float(value)
      true
    rescue StandardError
      false
    end

    def integer?(value)
      Integer(value)
      true
    rescue StandardError
      false
    end

    def valid_date?(string)
      return false unless string.is_a?(String)

      Date.strptime(string)
      true
    rescue ArgumentError
      false
    end

    def convert_to_date(string)
      datetime = Date.strptime(string)
      return Date.parse(string).strftime('%Y/%m/%d') if datetime.year == 1

      datetime.strftime('%Y/%m/%d')
    rescue ArgumentError
      string
    end

    def snake_case(text)
      return text&.downcase if text&.match?(/\A[A-Z]+\z/)

      text
        .to_s
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
        .gsub(/([a-z])([A-Z])/, '\1_\2')
        .downcase
        .tr(' ', '_')
    end

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

    def reformat_dates_in_hash(data)
      case data
      when Hash
        data.each { |key, value| data[key] = reformat_dates_in_hash(value) }
      when Array
        data.map! { |element| reformat_dates_in_hash(element) }
      when String
        valid_date?(data) ? convert_to_date(data).to_s : data
      else
        data
      end
    end

    def merge_properties(old_data, new_data)
      return old_data unless old_data.is_a?(Hash) && new_data.is_a?(Hash)

      merged = old_data.dup
      new_data.each do |key, value|
        merged[key] =
          if merged[key].is_a?(Hash) && value.is_a?(Hash)
            merge_properties(merged[key], value)
          else
            value
          end
      end
      merged
    end

    def json_example_plus_one(string)
      if string =~ /(\d+)$/
        string.sub(/(\d+)$/, (::Regexp.last_match(1).to_i + 1).to_s)
      else
        string
      end
    end

    def format_path_to_title(path)
      cleaned_path = path.to_s.sub(%r{^/v\d+/}, '')
      cleaned_path.gsub!(/\{[^}]+\}/, '')
      cleaned_path.split('/').reject(&:empty?).map(&:capitalize).join(' ')
    end

    def dump_yaml(data)
      YAML.dump(convert_to_hash(reformat_dates_in_hash(data)))
    end

    def load_yaml(path)
      YAML.safe_load(
        File.read(path),
        aliases: true,
        permitted_classes: [Symbol, DateTime, Date, Time, ActiveSupport::HashWithIndifferentAccess],
        permitted_symbols: []
      )
    end
  end
end

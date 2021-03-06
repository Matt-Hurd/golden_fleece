require 'golden_fleece/utility'

# An ORM-independent recursive validator that goes down into every level of
# your nested JSON and applies various validation logic. ORM-specific validation
# classes should use this class for their core processing. Returns an array of
# error messages.

module GoldenFleece
  class ValidatorContext
    include Utility

    def initialize(record, attribute, persisted_json, schemas, parent_path)
      @persisted_json = persisted_json
      @schemas = schemas
      @parent_path = parent_path
      persisted_keys = if persisted_json && persisted_json.keys
        persisted_json.keys.map(&:to_sym)
      else
        []
      end
      schemas_keys = schemas ? schemas.keys : []
      @validatable_keys = (persisted_keys + schemas_keys).uniq
      @record = record
      @attribute = attribute
      @errors = []
    end

    def validate
      validatable_keys.each do |key|
        path = build_json_path(parent_path, key)

        if validate_key key, path
          schema = schemas[key]
          value = schema.value.compute(record)

          validate_type(value, schema.types, path)
          validate_format(value, schema.format, path)

          # If the key's value is a nested JSON object, recurse down
          errors << ValidatorContext.new(record, attribute, (persisted_json ? persisted_json[key.to_s] : nil), schemas[key], path).validate if value.is_a?(Hash)
        end
      end

      errors.flatten
    end

    private

    attr_reader :persisted_json, :schemas, :parent_path, :validatable_keys, :record, :attribute, :errors

    def validate_key(key, path)
      if schemas.keys.include? key
        true
      else
        errors << "Invalid key #{error_suffix(attribute, path)}"
        false
      end
    end

    def validate_type(value, valid_types, path)
      unless valid_types.any? { |valid_type| valid_type.matches? value }
        errors << "Invalid type at #{error_suffix(attribute, path)}, must be one of #{valid_types}"
      end
    end

    def validate_format(value, valid_format, path)
      if valid_format
        begin
          valid_format.validate record, value
        rescue Exception => e
          errors << "Invalid format at #{error_suffix(attribute, path)}: #{e.message}"
        end
      end
    end
  end
end

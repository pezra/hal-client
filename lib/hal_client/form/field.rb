class HalClient
  class Form
    # A single field in a form.
    #
    # Current implementation is very basic. It only understands
    # `hidden` and `string` field types. All other field types are
    # treated as `string` per the spec.
    class Field

      # Initializes a new field.
      #
      # parsed_json - the parsed JSON of the field
      def initialize(parsed_json)
        @aliases = extract_aliases(parsed_json)
        @value = extract_value(parsed_json)
        @type = extract_type(parsed_json)
        @path = extract_path(parsed_json)
      end

      # Returns the path to which this field should be encoded in JSON documents, if any.
      attr_reader :path

      def extract_answer(answers)
        return value if :hidden == type

        key = aliases.find{|maybe_key| answers.has_key?(maybe_key) }

        coerce_value(answers.fetch(key, value))
      end

      protected

      attr_reader :aliases, :value, :type

      def coerce_value(val)
        return val if :hidden == type
        return nil if val.nil?

        val.to_s
      end

      def extract_aliases(parsed_json)
        name = parsed_json.fetch("name") {
          raise ArgumentError, "field doesn't have a name"
        }

        [name, name.to_sym]
      end

      def extract_value(parsed_json)
        parsed_json.fetch("value", nil)
      end

      def extract_type(parsed_json)
        case parsed_json["type"]
        when /hidden/i
          :hidden
        else
          :string
        end
      end

      def extract_path(parsed_json)
        parsed_json["path"]
      end
    end
  end
end

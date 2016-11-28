require 'forwardable'
require 'addressable/template'

class HalClient
  # Interprets parsed JSON
  class Interpreter
    extend Forwardable

    # Collection of reserved properties
    # https://tools.ietf.org/html/draft-kelly-json-hal-07#section-4.1
    RESERVED_PROPERTIES = ['_links', '_embedded'].freeze

    def initialize(parsed_json)
      fail(InvalidRepresentationError) unless hashish?(parsed_json)

      @raw = parsed_json
    end

    # Returns hash of properties from `parsed_json`
    def extract_props()
      raw.reject{|k,_| RESERVED_PROPERTIES.include?(k) }
    end

    protected

    attr_reader :raw

    def hashish?(obj)
      obj.respond_to?(:[]) &&
        obj.respond_to?(:map)
    end

  end
end

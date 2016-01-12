require 'hal_client/representation'

require 'byebug'

class HalClient

  # HAL representation of a single link. Provides access to an embedded representation.
  class Link

    # Create a new Link
    #
    # options - name parameters
    #   :rel - This Link's rel property
    #   :target - An instance of Representation
    #   :template = A URI template ( https://www.rfc-editor.org/rfc/rfc6570.txt )
    def initialize(options)
      @rel = options[:rel]
      @target = options[:target]
      @template = options[:template]

      (fail ArgumentError, "A rel must be provided") if @rel.nil?

      if @target.nil? && @template.nil?
        (fail ArgumentError, "A target or template must be provided")
      end

      if @target && @template
        (fail ArgumentError, "Cannot provide both a target and a template")
      end

      if @target && !@target.kind_of?(Representation)
        fail InvalidRepresentationError, "Invalid HAL representation: #{target.inspect}"
      end

      if @template && !@template.kind_of?(Addressable::Template)
        fail InvalidRepresentationError, "Invalid Addressable::Template: #{template.inspect}"
      end
    end

    attr_accessor :rel, :target, :template

    def href
      templated? ? template.pattern : target.href
    end

    def templated?
      !template.nil?
    end

    def ==(other)
      if (href && other.respond_to?(:href)) && (rel && other.respond_to?(:rel))
        href == other.href && rel == other.rel
      else
        false
      end
    end
    alias :eql? :==


    def hash
      [rel, href].hash
    end

  end
end

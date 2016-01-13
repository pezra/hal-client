require 'hal_client/representation'

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

    # Returns the URL of the resource this link references.
    # In the case of a templated link, this is the unresolved url template pattern.
    def raw_href
      templated? ? template.pattern : target.href
    end

    # Returns true for a templated link, false for an ordinary (non-templated) link
    def templated?
      !template.nil?
    end

    # Links with the same href, same rel value, and the same 'templated' value are considered equal
    # Otherwise, they are considered unequal
    def ==(other)
      if other.respond_to?(:raw_href) && other.respond_to?(:rel)  && other.respond_to?(:templated?)
        (raw_href == other.raw_href) && (rel == other.rel)  && (templated? == other.templated?)
      else
        false
      end
    end
    alias :eql? :==


    # Differing Representations or Addressable::Templates with matching hrefs will get matching hash
    # values, since we are using raw_href and not the objects themselves when computing hash
    def hash
      [rel, raw_href, templated?].hash
    end

  end
end

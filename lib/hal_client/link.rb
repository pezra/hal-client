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
    def initialize(options)
      @rel = options[:rel]
      @target = options[:target]

      (fail ArgumentError, "A rel must be provided") if @rel.nil?

      (fail ArgumentError, "A target must be provided") if @target.nil?

      (fail InvalidRepresentationError, "Invalid HAL representation: #{target.inspect}") unless
         @target.kind_of?(Representation)
    end

    attr_accessor :rel, :target


    def ==(other)
      if (target && other.respond_to?(:target)) &&
        (rel && other.respond_to?(:rel))
        target == other.target && rel == other.rel
      else
        false
      end
    end
    alias :eql? :==


    def hash
      [rel, target].hash
    end

  end
end

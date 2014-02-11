class HalClient

  # A collection HAL representations
  class RepresentationSet
    include Enumerable
    extend Forwardable

    def initialize(reprs)
      @reprs = reprs
    end

    def_delegators :reprs, :each, :count, :empty?, :any?

    def related(link_rel, options={})
      RepresentationSet.new flat_map{|it| it.related(link_rel, options){[]}.to_a }
    end

    protected

    attr_reader :reprs
  end
end

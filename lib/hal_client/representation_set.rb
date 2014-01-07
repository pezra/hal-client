class HalClient

  # A collection HAL representations
  class RepresentationSet
    include Enumerable
    extend Forwardable

    def initialize(reprs)
      @reprs = reprs
    end

    def_delegators :reprs, :each, :count

    def related(link_rel)
      RepresentationSet.new flat_map{|it| it.related(link_rel).to_a }
    end

    protected

    attr_reader :reprs
  end
end
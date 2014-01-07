require 'forwardable'

class HalClient
  class Representation
    extend Forwardable

    def initialize(hal_client, halibut_repr)
      @hal_client = hal_client
      @rare_repr = halibut_repr  # not quite raw, just rare
    end

    def_delegators :rare_repr, :property, :href

    def fetch(item_key, default=nil, &default_proc)
      default_proc ||= ->{default}

      property(item_key) ||
        related(item_key) ||
        default_proc.call
    end

    def [](item_key)
      fetch(item_key, nil)
    end

    def related(link_rel)
      RepresentationSet.new embedded(link_rel) + linked(link_rel)
    end

    def related_hrefs(link_rel)
      (rare_repr.embedded.fetch(link_rel){[]} + rare_repr.links.fetch(link_rel){[]}).
        map(&:href)
    end

    protected
    attr_reader :rare_repr, :hal_client

    def embedded(link_rel)
      rare_repr.embedded.fetch(link_rel){[]}.map{|it| Representation.new hal_client, it}
    end

    def linked(link_rel)
      rare_repr.links.fetch(link_rel){[]}.map{|link| hal_client.get link.href }
    end

  end
end
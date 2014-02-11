require 'forwardable'
require 'addressable/template'

require 'hal_client'
require 'hal_client/representation_set'

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

    # If the link(s) are templated they will be expanded using
    # `options` before the links are followed.
    def related(link_rel, options = {})
      related_cache[[link_rel,options]] ||=
        begin
          related = RepresentationSet.new embedded(link_rel) + linked(link_rel, options)
          (raise KeyError, "No `#{link_rel}` relations found") if related.empty?
          related
        end
    end

    def related_hrefs(link_rel)
      (rare_repr.embedded.fetch(link_rel){[]} + rare_repr.links.fetch(link_rel){[]}).
        map(&:href)
    end

    protected
    attr_reader :rare_repr, :hal_client

    def related_cache
      @related_cache ||= {}
    end

    def embedded(link_rel)
      rare_repr.embedded.fetch(link_rel){[]}.map{|it| Representation.new hal_client, it}
    end

    def linked(link_rel, options)
      rare_repr.links.fetch(link_rel){[]}.
        map{|link| if link.templated?
                     Addressable::Template.new(link.href).expand(options).to_s
                   else
                     link.href
                   end }.
        map {|href| hal_client.get href }
    end

  end
end

require 'addressable/template'

class HalClient

  # Expands CURIEs to fully qualified URLs using a set of curie definitions.
  class CurieResolver

    # Initialize new CurieResolver
    #
    # curie_defs - Array of curie definition links (per the HAL spec)
    def initialize(curie_defs)
      curie_defs = [curie_defs].flatten
      @namespaces = interpret curie_defs
    end

    # Returns a an expanded version of `curie_or_uri` or the
    # input. The input is returned when `curie_or_uri` is not a curie
    # or is a curie whose namespace is not recognized.
    #
    # curie_or_uri - the (potential) curie to resolve
    def resolve(curie_or_uri)
      ns, short_name = split_curie curie_or_uri

      if ns && (namespaces.has_key? ns)
        namespaces[ns].expand(rel: short_name).to_s
      else
        curie_or_uri
      end
    end

    protected
    attr_reader :namespaces

    def split_curie(a_curie)
      curie_parts = /(?<ns>[^:]+):(?<short_name>.+)/.match(a_curie)

      if curie_parts
        [curie_parts[:ns], curie_parts[:short_name]]
      else
        [nil,nil]
      end
    end

    def interpret(curie_defs)
      Hash[curie_defs.map{|it|
             [it["name"], Addressable::Template.new(it["href"])]
           }]
    end

  end
end

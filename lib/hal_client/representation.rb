require 'forwardable'
require 'addressable/template'

require 'hal_client'
require 'hal_client/representation_set'

class HalClient

  # HAL representation of a single resource. Provides access to
  # properties, links and embedded representations.
  class Representation
    extend Forwardable

    # Create a new Representation
    #
    # hal_client - The HalClient instance to use when navigating.
    # parsed_json - A hash structure representing a single HAL
    #   document.
    def initialize(hal_client, parsed_json)
      @hal_client = hal_client
      @raw = parsed_json
    end

    # Returns The value of the specified property or the specified
    #   default value.
    #
    # name - The name of property of interest
    # default - an optional object that should be return if the
    #   specified property does not exist
    # default_proc - an option proc that will be called with `name`
    #  to produce default value if the specified property does not
    #  exist
    #
    # Raises KeyError if the specified property does not exist
    #   and no default nor default_proc is provided.
    def property(name, default=MISSING, &default_proc)
      default_proc ||= ->(_){ default} if default != MISSING

      raw.fetch(name.to_s, &default_proc)
    end

    # Returns the URL of the resource this representation represents.
    def href
      link_section.fetch("self").fetch("href")
    end

    # Returns the value of the specified property or representations
    #   of resources related via the specified link rel or the
    #   specified default value.
    #
    # name_or_rel - The name of property or link rel of interest
    # default - an optional object that should be return if the
    #   specified property or link does not exist
    # default_proc - an option proc that will be called with `name`
    #  to produce default value if the specified property or link does not
    #  exist
    #
    # Raises KeyError if the specified property or link does not exist
    #   and no default nor default_proc is provided.
    def fetch(name_or_rel, default=MISSING, &default_proc)
      item_key = name_or_rel
      default_proc ||= ->(_){default} if default != MISSING

      property(item_key) {
        related(item_key, &default_proc)
      }
    end

    # Returns the value of the specified property or representations
    #   of resources related via the specified link rel or nil
    #
    # name_or_rel - The name of property or link rel of interest
    def [](name_or_rel)
      item_key = name_or_rel
      fetch(item_key, nil)
    end

    # Returns representations of resources related via the specified
    #   link rel or the specified default value.
    #
    # name_or_rel - The name of property or link rel of interest
    # options - optional keys and values with which to expand any
    #   templated links that are encountered
    # default_proc - an option proc that will be called with `name`
    #  to produce default value if the specified property or link does not
    #  exist
    #
    # Raises KeyError if the specified link does not exist
    #   and no default_proc is provided.
    def related(link_rel, options = {}, &default_proc)
      default_proc ||= ->(link_rel){
        raise KeyError, "No resources are related via `#{link_rel}`"
      }

      embedded = embedded(link_rel)
      linked = linked(link_rel, options)

      if embedded or linked
        RepresentationSet.new (Array(embedded) + Array(linked))
      else
        default_proc.call link_rel
      end
    end

    # Returns urls of resources related via the specified
    #   link rel or the specified default value.
    #
    # name_or_rel - The name of property or link rel of interest
    # options - optional keys and values with which to expand any
    #   templated links that are encountered
    # default_proc - an option proc that will be called with `name`
    #  to produce default value if the specified property or link does not
    #  exist
    #
    # Raises KeyError if the specified link does not exist
    #   and no default_proc is provided.
    def related_hrefs(link_rel, options={}, &default_proc)
      default_proc ||= ->(link_rel){
        raise KeyError, "No resources are related via `#{link_rel}`"
      }

      embedded = embedded_section.fetch(link_rel, nil)
      linked = link_section.fetch(link_rel, nil)

      if embedded or linked
        (boxed embedded).map{|an_embed| href_of an_embed } +
          (boxed linked).map{|it| it.fetch("href", nil) }.
          compact
      else
        default_proc.call link_rel
      end
    end

    # Returns a short human readable description of this
    # representation.
    def to_s
      "#<" + self.class.name + ": " + href + ">"
    end

    protected
    attr_reader :raw, :hal_client

    MISSING = Object.new

    def link_section
      @link_section ||= fully_qualified raw.fetch("_links", {})
    end

    def embedded_section
      @embedded_section ||= fully_qualified raw.fetch("_embedded", {})
    end

    def href_of(embedded_repr)
      embedded_repr.fetch("_links", {}).fetch("self", {}).fetch("href", nil)
    end

    def embedded(link_rel)
      relations = boxed embedded_section.fetch(link_rel)

      relations.map{|it| Representation.new hal_client, it}

    rescue KeyError
      nil
    end

    def linked(link_rel, options)
      relations = boxed link_section.fetch(link_rel)

      relations.
        map {|link| href_from link, options }.
        map {|href| hal_client.get href }

    rescue KeyError
      nil
    end


    def boxed(list_hash_or_nil)
      if Hash === list_hash_or_nil
        [list_hash_or_nil]
      else
        Array list_hash_or_nil
      end
    end

    def href_from(link, options)
      raw_href = link.fetch('href')

      if link.fetch('templated', false)
        Addressable::Template.new(raw_href).expand(options).to_s
      else
        raw_href
      end
    end

    def fully_qualified(relations_section)
      Hash[relations_section.map {|rel, link_info|
        [(namespaces.resolve rel), link_info]
      }]
    end

    def namespaces
      @namespaces ||= CurieResolver.new raw.fetch("_links", {}).fetch("curies", [])
    end



  end
end

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
    # parsed_json - A hash structure representing a single HAL
    #   document.
    # href - The href of this representation.
    # hal_client - The HalClient instance to use when navigating.
    #
    # Signature
    #
    #     initialize(hal_client, parsed_json)
    #     initialize(parsed_json, hal_client)
    #
    # Initialize this representation with a parsed json document and a
    # hal_client with which to make requests.
    #
    #     initialize(href, hal_client)
    #
    # Initialize this representation with an href and a hal_client
    # with which to make requests. Any attempt to retrieve properties
    # or related representations will result in the href being
    # dereferenced.
    #
    #     initialize(href)
    #
    # Initialize this representation with an href. The representation
    # will not be able to make requests to dereference itself but this
    # can still be useful in test situations to maintain a uniform
    # interface.
    #
    #     initialize(parse_json)
    #
    # Initializes representation that cannot request related
    # representations.
    #
    def initialize(*args)
      (raise ArgumentError, "wrong number of arguments (#{args.size} for 1 or 2)") if
        args.size > 2

      @raw = args.find {|it| (it.respond_to? :has_key?) &&  (it.respond_to? :fetch) }
      @hal_client = args.find {|it| HalClient === it }

      if @raw.nil?
        @href = args.find {|it| it.respond_to? :downcase }
      end
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
      @href ||= link_section.fetch("self").fetch("href")
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

    # Returns true if this representation contains a link (including
    # embedded links) whose rel is `link_rel`.
    #
    # link_rel - The link rel of interest
    def has_related?(link_rel)
      _ = related link_rel
      true
    rescue KeyError
      false
    end

    # Returns representations of resources related via the specified
    #   link rel or the specified default value.
    #
    # link_rel - The link rel of interest
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

      embedded = embedded_or_nil(link_rel)
      linked = linked_or_nil(link_rel, options)

      if !embedded.nil? or !linked.nil?
        RepresentationSet.new (Array(embedded) + Array(linked))
      else
        default_proc.call link_rel
      end
    end

    # Returns urls of resources related via the specified
    #   link rel or the specified default value.
    #
    # link_rel - The link rel of interest
    # options - optional keys and values with which to expand any
    #   templated links that are encountered
    # default_proc - an option proc that will be called with `name`
    #  to produce default value if the specified property or link does not
    #  exist
    #
    # Raises KeyError if the specified link does not exist
    #   and no default_proc is provided.
    def related_hrefs(link_rel, options={}, &default_proc)
      related(link_rel, options, &default_proc).
        map(&:href)
    end

    # Returns a short human readable description of this
    # representation.
    def to_s
      "#<" + self.class.name + ": " + href + ">"
    end

    protected
    attr_reader :hal_client

    MISSING = Object.new

    def raw
      @raw ||= hal_client.get(href)
    end

    def link_section
      @link_section ||= fully_qualified raw.fetch("_links", {})
    end

    def embedded_section
      @embedded_section ||= fully_qualified raw.fetch("_embedded", {})
    end

    def embedded(link_rel)
      relations = boxed embedded_section.fetch(link_rel)

      relations.map{|it| Representation.new hal_client, it}
    end

    def embedded_or_nil(link_rel)
      embedded link_rel

    rescue KeyError
      nil
    end

    def linked(link_rel, options)
      relations = boxed link_section.fetch(link_rel)

      relations.
        map {|link| href_from link, options }.
        map {|href| Representation.new href, hal_client }
    end

    def linked_or_nil(link_rel, options)
      linked link_rel, options

    rescue KeyError
      nil
    end


    def boxed(list_hash_or_nil)
      if Hash === list_hash_or_nil
        [list_hash_or_nil]
      else
        list_hash_or_nil
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

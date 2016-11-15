require 'forwardable'
require 'addressable/template'

require 'hal_client'
require 'hal_client/representation_set'

class HalClient

  # HAL representation of a single resource. Provides access to
  # properties, links and embedded representations.
  class Representation
    extend Forwardable

    # Collection of reserved properties
    # https://tools.ietf.org/html/draft-kelly-json-hal-07#section-4.1
    RESERVED_PROPERTIES = ['_links', '_embedded'].freeze

    NO_RELATED_RESOURCE = ->(link_rel) {
      raise KeyError, "No resources are related via `#{link_rel}`"
    }

    NO_EMBED_FOUND = ->(link_rel) {
      raise KeyError, "#{link_rel} embed not found"
    }

    NO_LINK_FOUND = ->(link_rel, _options) {
      raise KeyError, "#{link_rel} link not found"
    }

    private_constant :NO_RELATED_RESOURCE, :NO_EMBED_FOUND, :NO_LINK_FOUND

    # Create a new Representation
    #
    # options - name parameters
    #   :parsed_json - A hash structure representing a single HAL
    #     document.
    #   :href - The href of this representation.
    #   :hal_client - The HalClient instance to use when navigating.
    def initialize(options)
      @raw = options[:parsed_json]
      @hal_client = options[:hal_client]
      @href = options[:href]

      (fail ArgumentError, "Either parsed_json or href must be provided") if
        @raw.nil? && @href.nil?

      (fail InvalidRepresentationError, "Invalid HAL representation: #{raw.inspect}") if
        @raw && ! hashish?(@raw)
    end

    # Posts a `Representation` or `String` to this resource. Causes
    # this representation to be reloaded the next time it is used.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#post`
    def post(data, options={})
      @hal_client.post(href, data, options).tap do
        reset
      end
    end

    # Puts a `Representation` or `String` to this resource. Causes
    # this representation to be reloaded the next time it is used.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#put`
    def put(data, options={})
      @hal_client.put(href, data, options).tap do
        reset
      end
    end

    # Patchs a `Representation` or `String` to this resource. Causes
    # this representation to be reloaded the next time it is used.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#patch`
    def patch(data, options={})
      @hal_client.patch(href, data, options).tap do
        reset
      end
    end

    # Returns true if this representation contains the specified
    # property.
    #
    # name - the name of the property to check
    def property?(name)
      raw.key? name
    end
    alias_method :has_property?, :property?

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

    # Returns a Hash including the key-value pairs of all the properties
    #   in the resource. It does not include HAL's reserved
    #   properties (`_links` and `_embedded`).
    def properties
      raw.reject { |k, _| RESERVED_PROPERTIES.include? k }
    end

    # Returns the URL of the resource this representation represents.
    def href
      @href ||= raw
              .fetch("_links",{})
              .fetch("self",{})
              .fetch("href",nil)
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
    def related?(link_rel)
      !!(linked(link_rel) { false } || embedded(link_rel) { false })
    end
    alias_method :has_related?, :related?

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
      default_proc ||= NO_RELATED_RESOURCE

      embedded = embedded(link_rel) { nil }
      linked = linked(link_rel, options) { nil }
      return default_proc.call(link_rel) if embedded.nil? and linked.nil?

      RepresentationSet.new (Array(embedded) + Array(linked))
    end

    def all_links
      result = Set.new
      base_url = Addressable::URI.parse(href || "")

      embedded_entries = flatten_section(raw.fetch("_embedded", {}))
      result.merge(embedded_entries.map do |entry|
        Link.new_from_embedded_entry(hash_entry: entry,
                                     hal_client: hal_client,
                                     curie_resolver: namespaces,
                                     base_url: base_url)
      end)

      link_entries = flatten_section(raw.fetch("_links", {}))
      result.merge(link_entries.map { |entry|
        Link.new_from_link_entry(hash_entry: entry,
                                 hal_client: hal_client,
                                 curie_resolver: namespaces,
                                 base_url: base_url) })

      result
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

    # Returns values of the `href` member of links and the URL of
    # embedded representations related via the specified link rel. The
    # only difference between this and `#related_hrefs` is that this
    # method makes no attempt to expand templated links. For templated
    # links the returned collection will include the template pattern
    # as encoded in the HAL document.
    #
    # link_rel - The link rel of interest
    # default_proc - an option proc that will be called with `name`
    #  to produce default value if the specified property or link does not
    #  exist
    #
    # Raises KeyError if the specified link does not exist
    #   and no default_proc is provided.
    def raw_related_hrefs(link_rel, &default_proc)
      default_proc ||= NO_RELATED_RESOURCE

      embedded = embedded(link_rel) { nil }
      linked = links.hrefs(link_rel) { nil }
      return default_proc.call(link_rel) if embedded.nil? and linked.nil?

      Array(linked) + Array(embedded).map(&:href)
    end

    # Returns an Enumerable of the items in this collection resource
    # if this is an rfc 6573 collection.
    #
    # Raises HalClient::NotACollectionError if this is not a
    # collection resource.
    def as_enum
      Collection.new(self)
    end

    # Returns an Enumerator of the items in the collection resource
    # if this is an rfc 6573 collection.
    #
    # Raises HalClient::NotACollectionError if this is not a
    # collection resource.
    def to_enum(method=:each, *args, &blk)
      as_enum.to_enum(method, *args, &blk)
    end

    # Resets this representation such that it will be requested from
    # the upstream on it's next use.
    def reset
      @href = href # make sure we have the href
      @raw = nil
    end

    # Returns a short human readable description of this
    # representation.
    def to_s
      "#<" + self.class.name + ": " + (href || "ANONYMOUS")  + ">"
    end

    # Returns the raw json representation of this representation
    def to_json
      MultiJson.dump(raw)
    end
    alias_method :to_hal, :to_json

    def hash
      if href
        href.hash
      else
        @raw.hash
      end
    end

    def ==(other)
      if href && other.respond_to?(:href)
        href == other.href
      elsif other.respond_to?(:raw)
        @raw == other.raw
      else
        false
      end
    end
    alias :eql? :==

    # Internal: Returns parsed json document
    def raw
      if @raw.nil? && @href
        (fail "unable to make requests due to missing hal client") unless hal_client

        response = hal_client.get(@href)

        unless response.is_a?(Representation)
          error_message = "Response body wasn't a valid HAL document:\n\n"
          error_message += response.body
          raise InvalidRepresentationError.new(error_message)
        end

        @raw ||= response.raw
      end

      @raw
    end

    # Internal: Returns the HalClient used to retrieve this
    # representation
    attr_reader :hal_client

    protected

    MISSING = Object.new

    def flatten_section(section_hash)
      section_hash
        .each_pair
        .flat_map { |rel, some_link_info|
          [some_link_info].flatten
          .map { |a_link_info| { rel: rel, data: a_link_info } }
      }
    end

    def links
      @links ||= LinksSection.new((raw.fetch("_links"){{}}),
                                  base_url: Addressable::URI.parse(href || ""))
    end

    def embedded_section
      embedded = raw.fetch("_embedded", {})

      @embedded_section ||= embedded.merge fully_qualified(embedded)
    end

    def embedded(link_rel, &default_proc)
      default_proc ||= NO_EMBED_FOUND

      relations = embedded_section.fetch(link_rel) { MISSING }
      return default_proc.call(link_rel) if relations == MISSING

      (boxed relations).map{|it| Representation.new hal_client: hal_client, parsed_json: it}

    rescue InvalidRepresentationError
      fail InvalidRepresentationError, "/_embedded/#{jpointer_esc(link_rel)} is not a valid representation"
    end

    def linked(link_rel, options = {}, &default_proc)
      default_proc ||= NO_LINK_FOUND

      relations = links.hrefs(link_rel) { MISSING }
      return default_proc.call(link_rel, options) if relations == MISSING || relations.compact.empty?

      relations
        .map {|url_or_tmpl|
          if url_or_tmpl.respond_to? :expand
            url_or_tmpl.expand(options).to_s
          else
            url_or_tmpl
          end }
        .map {|href| Representation.new href: href, hal_client: hal_client }

    rescue InvalidRepresentationError
      fail InvalidRepresentationError, "/_links/#{jpointer_esc(link_rel)} is not a valid link"
    end

    def jpointer_esc(str)
      str.gsub "/", "~1"
    end

    def boxed(list_hash_or_nil)
      if hashish? list_hash_or_nil
        [list_hash_or_nil]
      elsif list_hash_or_nil.respond_to? :map
        list_hash_or_nil
      else
        # The only valid values for a link/embedded set are hashes or
        # array-ish things.

        fail InvalidRepresentationError
      end
    end

    def fully_qualified(relations_section)
      Hash[relations_section.map {|rel, link_info|
        [(namespaces.resolve rel), link_info]
      }]
    end

    def hashish?(thing)
      thing.respond_to?(:fetch) && thing.respond_to?(:key?)
    end

    def_delegators :links, :namespaces
  end
end

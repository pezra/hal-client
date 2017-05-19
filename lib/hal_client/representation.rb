require 'forwardable'
require 'addressable/template'

require 'hal_client'
require 'hal_client/representation_set'
require 'hal_client/interpreter'
require 'hal_client/anonymous_resource_locator'

class HalClient
  # HAL representation of a single resource. Provides access to
  # properties, links and embedded representations.
  #
  # Operations on a representation are not thread-safe.  If you'd like to
  # use representations in a threaded environment, consider using the method
  # #clone_for_use_in_different_thread to create a copy for each new thread
  class Representation
    extend Forwardable

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
      @hal_client = options[:hal_client]
      @href = options[:href]

      interpret options[:parsed_json] if options[:parsed_json]

      (fail ArgumentError, "Either parsed_json or href must be provided") if
        @raw.nil? && @href.nil?
    end

    # Returns a copy of this instance that is safe to use in threaded
    # environments
    def clone_for_use_in_different_thread
      clone.tap do |c|
        c.hal_client = c.hal_client.clone_for_use_in_different_thread
      end
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
      ensure_reified
      properties.key? name
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
      ensure_reified

      default_proc ||= ->(_){ default} if default != MISSING

      properties.fetch(name.to_s, &default_proc)
    end

    # Returns a Hash including the key-value pairs of all the properties
    #   in the resource. It does not include HAL's reserved
    #   properties (`_links` and `_embedded`).
    attr_reader :properties

    # Returns the URL of the resource this representation represents.
    def href
      @href ||= raw
              .fetch("_links",{})
              .fetch("self",{})
              .fetch("href", AnonymousResourceLocator.new)
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
      links_by_rel.key?(link_rel)
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

      ensure_reified

      related = links_by_rel
                .fetch(link_rel) { return default_proc.call(link_rel) }
                .map { |l| l.target(options) }

      RepresentationSet.new(related)
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

      ensure_reified

      links_by_rel
        .fetch(link_rel) { return default_proc.call(link_rel) }
        .map { |l| l.raw_href }
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

    # Returns set of all links in this representation.
    def all_links
      links_by_rel
        .reduce(Set.new) { |result, kv|
          _,links = *kv
          links.each { |l| result << l }
          result
        }
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
      "#<" + self.class.name + ": " + href.to_s  + ">"
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

    # Returns raw parsed json.
    def raw
      ensure_reified

      @raw
    end

    # Return the HalClient used to retrieve this representation
    attr_reader :hal_client

    protected

    attr_reader :links_by_rel
    attr_writer :hal_client

    MISSING = Object.new

    # Fetch the representation from origin server if that has not already
    # happened.
    def ensure_reified
      return if @raw
      (fail "unable to make requests due to missing hal client") unless hal_client
      (fail "unable to make requests due to missing href") unless @href

      response = hal_client.get(@href)

      unless response.is_a?(Representation)
        error_message = "Response body wasn't a valid HAL document:\n\n"
        error_message += response.body
        raise InvalidRepresentationError.new(error_message)
      end

      interpret response.raw
    end

    def interpret(parsed_json)
      @raw = parsed_json

      interpreter = HalClient::Interpreter.new(parsed_json, hal_client)

      @properties = interpreter.extract_props

      @links_by_rel =
        interpreter
        .extract_links
        .reduce(Hash.new { |h,k| h[k] = Set.new }) { |links_tab, link|
          links_tab[link.literal_rel] << link
          links_tab[link.fully_qualified_rel] << link
          links_tab
        }
    end

    def_delegators :links, :namespaces
  end
end

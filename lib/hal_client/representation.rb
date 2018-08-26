require 'forwardable'
require 'addressable/template'

require_relative '../hal_client'
require_relative 'errors'
require_relative 'representation_set'
require_relative 'interpreter'
require_relative 'anonymous_resource_locator'
require_relative 'form'

class HalClient
  # HAL representation of a single resource. Provides access to
  # properties, links and embedded representations.
  #
  # Operations on a representation are not thread-safe.
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

    class << self
      # Create a new Representation
      #
      # Signature
      #   new(parsed_json:, href: nil, hal_client: nil)
      #   new(href:, hal_client:)
      #   new(location, props, links, hal_client)
      #
      def new(*args)
        if args.count == 1 && (opts=args.first).key?(:parsed_json)
          # deprecated options style creation
          Interpreter.new(opts[:parsed_json], opts[:hal_client],
                          content_location: opts[:href]).extract_repr

        elsif args.count == 1 && args.first.key?(:href)
          # deprecated options style creation
          RepresentationFuture.new(opts[:href],
                                   opts.fetch(:hal_client){raise ArgumentError, "you must specify parsed_json or hal_client"})

        else
          super(*args)
        end
      end
    end

    # Create a new Representation
    #
    # location - the location of the resource this represents
    # properties - `Hash` of properties
    # links - `Enumerable` of `Link`s
    # hal_client - `HalClient` to use for navigation
    def initialize(location, properties, links, hal_client)
      @href = location
      @hal_client = hal_client
      @properties = properties
      @links_by_rel = index_links(links)
    end

    # Returns a copy of this instance that is safe to use in threaded
    # environments
    def clone_for_use_in_different_thread
      clone.tap do |c|
        if c.hal_client
          c.hal_client = c.hal_client.clone_for_use_in_different_thread
        end
      end
    end

    # Posts a `Representation` or `String` to this resource. Causes
    # this representation to be reloaded the next time it is used.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#post`
    def post(data, options={})
      @hal_client.post(href, data, options).tap do
        stale!
      end
    end

    # Puts a `Representation` or `String` to this resource. Causes
    # this representation to be reloaded the next time it is used.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#put`
    def put(data, options={})
      @hal_client.put(href, data, options).tap do
        stale!
      end
    end

    # Patchs a `Representation` or `String` to this resource. Causes
    # this representation to be reloaded the next time it is used.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#patch`
    def patch(data, options={})
      @hal_client.patch(href, data, options).tap do
        stale!
      end
    end

    # Returns true if this representation contains the specified
    # property.
    #
    # name - the name of the property to check
    def property?(name)
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
      default_proc ||= ->(_){ default} if default != MISSING

      properties.fetch(name.to_s, &default_proc)
    end

    # Returns a Hash including the key-value pairs of all the properties
    #   in the resource. It does not include HAL's reserved
    #   properties (`_links` and `_embedded`).
    def properties
      (fail StaleRepresentationError) if @stale

      @properties
    end
    # Returns the URL of the resource this represents.
    attr_reader :href

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

    # Returns the specified `Form`
    #
    # form_id - the string or symbol id of the form of interest. Default: `"default"`
    #
    # Raises `KeyError` if the specified form doesn't exist.
    def form(form_id="default")
      parsed_form_json = property("_forms").fetch(form_id.to_s)

      Form.new(parsed_form_json, hal_client)
    end


    # Mark this representation as stale. Used to flag representations
    # that have been updated on the server at such.
    def stale!
      @stale=true
    end

    # Returns a short human readable description of this
    # representation.
    def to_s
      "#<" + self.class.name + ": " + href.to_s  + ">"
    end

    def inspect
      %Q|#<#{self.class.name} #{href.to_s} @properties=#{properties} @links=#{all_links}">|
    end

    def pretty_print(pp)
      pp.text "#<#{self.class.name}"
      pp.fill_breakable
      pp.text href.to_s

      pp.fill_breakable
      pp.text "@properties="
      pp.group_sub do
        properties.pretty_print(pp)
      end

      pp.fill_breakable
      pp.text "@links="
      pp.group_sub do
        all_links.pretty_print(pp)
      end
      pp.text ">"
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

    # Returns a JSON hash semantically equivalent to, but not exactly
    # the same as, the JSON that was parsed to create this
    # representation.
    #
    # ---
    #
    # Hard to know what to do with embedding. We don't currently know if the 
    def raw
      properties.tap do |hsh|
        hsh.merge!("_links" => links_hash) if links_hash.any?
        hsh.merge!("_embedded" => embedded_hash) if embedded_hash.any?
      end
    end

    # Return the HalClient used to retrieve this representation
    attr_reader :hal_client

    protected

    MISSING = Object.new

    attr_writer :hal_client

    def links_by_rel
      (fail StaleRepresentationError) if @stale

      @links_by_rel
    end

    def links_hash
      all_links
        .reject{|l| AnonymousResourceLocator === l.target_url }
        .group_by(&:literal_rel)
        .reduce({}) { |acc, (rel, links)|
          link_objs = links.map{|l| {"href" => l.href_str, "templated" => l.templated?} }
          link_objs = link_objs.first if link_objs.count == 1

          acc[rel] = link_objs
          acc
        }
    end

    def embedded_hash
      all_links
        .select(&:embedded?)
        .group_by(&:literal_rel)
        .reduce({}) { |acc, (rel, links)|
          embedded_objs = links.map{|l| l.target.raw}
          embedded_objs = embedded_objs.first if embedded_objs.count == 1

          acc[rel] = embedded_objs
          acc
        }
    end

    def index_links(links)
      links.reduce(Hash.new { |h,k| h[k] = Set.new }) { |links_tab, link|
          links_tab[link.literal_rel] << link
          links_tab[link.fully_qualified_rel] << link
          links_tab
        }
    end

    def_delegators :links, :namespaces
  end
end

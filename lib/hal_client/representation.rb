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

    # Posts a `Representation` or `String` to this resource.
    #
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `HalClient#post`
    def post(data, options={})
      @hal_client.post(href, data, options)
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

    # Returns the raw json representation of this representation
    def to_json
      raw.to_json
    end

    protected
    attr_reader :hal_client

    MISSING = Object.new

    def raw
      if @raw.nil? && @href
        (fail "unable to make requests due to missing hal client") unless hal_client
        @raw ||= hal_client.get(@href).raw
      end

      @raw
    end

    def link_section
      @link_section ||= fully_qualified raw.fetch("_links", {})
    end

    def embedded_section
      @embedded_section ||= fully_qualified raw.fetch("_embedded", {})
    end

    def embedded(link_rel)
      relations = boxed embedded_section.fetch(link_rel)

      relations.map{|it| Representation.new hal_client: hal_client, parsed_json: it}

    rescue InvalidRepresentationError => err
      fail InvalidRepresentationError, "/_embedded/#{jpointer_esc(link_rel)} is not a valid representation"
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
        map {|href| Representation.new href: href, hal_client: hal_client }

    rescue InvalidRepresentationError => err
      fail InvalidRepresentationError, "/_links/#{jpointer_esc(link_rel)} is not a valid link"
    end

    def jpointer_esc(str)
      str.gsub "/", "~1"
    end

    def linked_or_nil(link_rel, options)
      linked link_rel, options

    rescue KeyError
      nil
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

    def hashish?(thing)
      thing.respond_to?(:fetch) && thing.respond_to?(:key?)
    end

  end
end

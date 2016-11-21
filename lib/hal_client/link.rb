require 'hal_client/representation'

class HalClient

  # HAL representation of a single link. Provides access to an embedded representation.
  class Link
    protected def initialize(rel:, curie_resolver: CurieResolver.new([]), **opts)
      @literal_rel = rel
      @curie_resolver = curie_resolver

      post_initialize(opts)
    end

    def raw_href
      raise NotImplementedError
    end

    def target_url(vars = {})
      raise NotImplementedError
    end

    def target(vars = {})
      raise NotImplementedError
    end

    def templated?
      raise NotImplementedError
    end

    attr_reader :literal_rel, :curie_resolver

    def fully_qualified_rel
      curie_resolver.resolve(literal_rel)
    end

    alias_method :target, :target_url

    # Links with the same href, same rel value, and the same 'templated' value
    # are considered equal Otherwise, they are considered unequal
    def ==(other)
      if other.respond_to?(:raw_href) &&
         other.respond_to?(:fully_qualified_rel) &&
         other.respond_to?(:templated?)
        (raw_href == other.raw_href) &&
          (fully_qualified_rel == other.fully_qualified_rel) &&
          (templated? == other.templated?)
      else
        false
      end
    end
    alias :eql? :==

    # Differing Representations or Addressable::Templates with matching hrefs will get matching hash
    # values, since we are using raw_href and not the objects themselves when computing hash
    def hash
      [fully_qualified_rel, raw_href, templated?].hash
    end

    protected

    def post_initialize(opts)
    end

    # Create a new Link using an entry from the '_links' section of a HAL document
    #
    # options - name parameters
    #   :hash_entry - a hash containing keys :rel (string) and :data (hash from a '_links' entry)
    #   :hal_client - an instance of HalClient
    #   :curie_resolver - An instance of CurieResolver (used to resolve curied rels)
    #   :base_url - Base url for resolving relative links in hash_entry (probably the parent
    # document's "self" link)
    def self.new_from_link_entry(options)
      hash_entry = options[:hash_entry]
      hal_client = options[:hal_client]
      curie_resolver = options[:curie_resolver]
      base_url = options[:base_url]

      rel = hash_entry[:rel]
      hash_data = hash_entry[:data]
      return nil unless hash_data['href']
      href = (base_url + hash_data['href']).to_s

      if hash_data['templated']
        TemplatedLink.new(rel: rel,
                          template: Addressable::Template.new(href),
                          curie_resolver: curie_resolver)
      else
        SimpleLink.new(rel: rel,
                       target: Representation.new(hal_client: hal_client, href: href),
                       curie_resolver: curie_resolver)
      end
    end


    # Create a new Link using an entry from the '_embedded' section of a HAL document
    #
    # options - name parameters
    #   :hash_entry - a hash containing keys :rel (string) and :data (hash from a '_embedded' entry)
    #   :hal_client - an instance of HalClient
    #   :curie_resolver - An instance of CurieResolver (used to resolve curied rels)
    #   :base_url - Base url for resolving relative links in hash_entry (probably the parent
    # document's "self" link)
    def self.new_from_embedded_entry(options)
      hash_entry = options[:hash_entry]
      hal_client = options[:hal_client]
      curie_resolver = options[:curie_resolver]
      base_url = options[:base_url]

      rel = hash_entry[:rel]
      hash_data = hash_entry[:data]

      explicit_url = self_href(hash_data)
      hash_data['_links']['self']['href'] = (base_url + explicit_url).to_s if explicit_url

      SimpleLink.new(rel: rel,
                     target: Representation.new(hal_client: hal_client, parsed_json: hash_data),
                     curie_resolver: curie_resolver)
    end

    def self.self_href(embedded_repr)
      embedded_repr
        .fetch('_links', {})
        .fetch('self', {})
        .fetch('href', nil)
    end

  end

  class SimpleLink < Link

    protected def post_initialize(target:)
      fail(ArgumentError) unless target.kind_of?(HalClient::Representation)

      @target = target
    end

    attr_accessor :target

    def raw_href
      target.href.to_s
    end

    def templated?
      false
    end

    def target_url(_vars = {})
      target.href
    end
  end


  class TemplatedLink < Link
    protected def post_initialize(template:)
      fail(ArgumentError) unless template.kind_of? Addressable::Template
      @tmpl = template
    end

    def raw_href
      tmpl.pattern
    end

    def templated?
      true
    end

    def target_url(vars = {})
      tmpl.expand(vars)
    end

    protected

    attr_reader :tmpl
  end

  # class EmbeddedLink < Link
  #   protected def post_initialize(target:)
  #     @target_repr = target
  #   end

  #   def raw_href
  #     target_repr.href.to_s
  #   end

  #   alias_method :target_url, :raw_href

  #   def templated?
  #     false
  #   end

  #   protected

  #   attr_reader :target_repr
  # end



end

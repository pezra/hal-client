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

    def embedded?
      raise NotImplementedError
    end

    def href_str
      raise NotImplementedError
    end

    attr_reader :literal_rel, :curie_resolver

    def fully_qualified_rel
      curie_resolver.resolve(literal_rel)
    end

    def rel?(a_rel)
      self.literal_rel == a_rel || self.fully_qualified_rel == a_rel
    end

    # Links with the same href, same rel value, and the same 'templated' value
    # are considered equal. Otherwise, they are considered unequal. Links
    # without a href (for example anonymous embedded links, are never equal to
    # one another.
    def ==(other)
      return false if raw_href.nil? || AnonymousResourceLocator === raw_href

      return false unless other.respond_to?(:href_str) &&
                          other.respond_to?(:fully_qualified_rel) &&
                          other.respond_to?(:templated?)


      (href_str == other.href_str) &&
        (fully_qualified_rel == other.fully_qualified_rel) &&
        (templated? == other.templated?)
    end
    alias :eql? :==

    # Differing Representations or Addressable::Templates with matching hrefs
    # will get matching hash values, since we are using href_str and not the
    # objects themselves when computing hash
    def hash
      [fully_qualified_rel,
       href_str,
       templated?].hash
    end

    protected

    def post_initialize(opts)
    end

  end

  # Links that are not templated.
  class SimpleLink < Link

    protected def post_initialize(target:, embedded:)
      fail(ArgumentError) unless target.respond_to?(:href)

      @target = target
      @embedded = embedded
    end

    # Returns `Addressable::URI` or `Addressable::Template` of the link's href.
    def raw_href
      target.href
    end

    # Returns true iff this link is templated.
    def templated?
      false
    end

    # Returns true iff this links is embedded.
    def embedded?
      @embedded
    end

    # Returns the URI (`Addressable::URI`) targeted by this link.
    def target_url(_vars = {})
      target.href
    end

    # Returns a `HalClient::Representation` of the target of this link.
    def target(_vars = {})
      @target
    end

    # Returns a `String` version of the target URI or URI template of this link.
    def href_str
      target_url.to_s
    end
  end

  # Links that are templated.
  class TemplatedLink < Link

    protected def post_initialize(template:, hal_client:)
      fail(ArgumentError) unless template.kind_of? Addressable::Template
      @tmpl = template
      @hal_client = hal_client
    end

    def raw_href
      tmpl
    end

    def templated?
      true
    end

    def target_url(vars = {})
      tmpl.expand(vars)
    end

    def target(vars = {})
      RepresentationFuture.new(target_url(vars), hal_client)
    end

    def embedded?
      false
    end

    def href_str
      tmpl.pattern
    end


    # Differing Representations or Addressable::Templates with matching hrefs
    # will get matching hash values, since we are using raw_href and not the
    # objects themselves when computing hash
    def hash
      [fully_qualified_rel,
       tmpl.pattern,
       templated?].hash
    end

    protected

    attr_reader :tmpl, :hal_client
  end

  # A link that was malformed in the JSON. This class is used to delay
  # presenting interpretation errors so that consumers can ignore malformedness
  # that does not block their goal. For example, busted links that they will not
  # use anyway.
  class MalformedLink < Link

    protected def post_initialize(msg:)
      @msg = msg
    end

    def raise_invalid(**)
      raise InvalidRepresentationError, msg
    end

    alias_method :raw_href, :raise_invalid
    alias_method :target_url, :raise_invalid
    alias_method :target, :raise_invalid
    alias_method :templated?, :raise_invalid
    alias_method :embedded?, :raise_invalid
    alias_method :href_str, :raise_invalid

    def hash
      fully_qualified_rel.hash
    end

    protected

    attr_reader :msg
  end


end

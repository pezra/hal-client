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

    # Links with the same href, same rel value, and the same 'templated' value
    # are considered equal. Otherwise, they are considered unequal. Links
    # without a href (for example anonymous embedded links, are never equal to
    # one another.
    def ==(other)
      return false if raw_href.nil?

      return false unless other.respond_to?(:raw_href) &&
                          other.respond_to?(:fully_qualified_rel) &&
                          other.respond_to?(:templated?)


      (raw_href == other.raw_href) &&
        (fully_qualified_rel == other.fully_qualified_rel) &&
        (templated? == other.templated?)
    end
    alias :eql? :==

    # Differing Representations or Addressable::Templates with matching hrefs
    # will get matching hash values, since we are using raw_href and not the
    # objects themselves when computing hash
    def hash
      [fully_qualified_rel,
       raw_href,
       templated?].hash
    end

    protected

    def post_initialize(opts)
    end

  end

  # Links that are not templated.
  class SimpleLink < Link

    protected def post_initialize(target:)
      fail(ArgumentError) unless target.kind_of?(HalClient::Representation)

      @target = target
    end

    def raw_href
      target.href
    end

    def templated?
      false
    end

    def target_url(_vars = {})
      target.href
    end

    def target(_vars = {})
      @target
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
      Representation.new(href: target_url(vars), hal_client: hal_client)
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

    def hash
      fully_qualified_rel.hash
    end

    protected

    attr_reader :msg
  end


end

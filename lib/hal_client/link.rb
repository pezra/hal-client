require 'hal_client/representation'

class HalClient

  # HAL representation of a single link. Provides access to an embedded representation.
  class Link

    # Create a new Link
    #
    # options - name parameters
    #   :rel - This Link's rel property
    #   :target - An instance of Representation
    #   :template = A URI template ( https://www.rfc-editor.org/rfc/rfc6570.txt )
    def initialize(options)
      @rel = options[:rel]
      @target = options[:target]
      @template = options[:template]
      @curie_resolver = options[:curie_resolver] || CurieResolver.new([])

      (fail ArgumentError, "A rel must be provided") if @rel.nil?

      if @target.nil? && @template.nil?
        (fail ArgumentError, "A target or template must be provided")
      end

      if @target && @template
        (fail ArgumentError, "Cannot provide both a target and a template")
      end

      if @target && !@target.kind_of?(Representation)
        (fail ArgumentError, "Invalid HAL representation: #{target.inspect}")
      end

      if @template && !@template.kind_of?(Addressable::Template)
        (fail ArgumentError, "Invalid Addressable::Template: #{template.inspect}")
      end
    end

    attr_accessor :rel, :target, :template, :curie_resolver

    def self.new_from_link_entry(hash_entry:, hal_client:, curie_resolver:, base_url:)
      rel = hash_entry[:rel]
      hash_data = hash_entry[:data]
      href = (Addressable::URI.parse(base_url) + hash_data['href']).to_s

      if hash_data['templated']
        Link.new(rel: rel,
                 template: Addressable::Template.new(href),
                 curie_resolver: curie_resolver)
      else
        Link.new(rel: rel,
                 target: Representation.new(hal_client: hal_client, href: href),
                 curie_resolver: curie_resolver)
      end
    end

    def self.new_from_embedded_entry(hash_entry:, hal_client:, curie_resolver:, base_url:)
      rel = hash_entry[:rel]
      hash_data = hash_entry[:data]

      absolute_href = (Addressable::URI.parse(base_url) + hash_data['_links']['self']['href']).to_s
      hash_data['_links']['self']['href'] = absolute_href

      Link.new(rel: rel,
               target: Representation.new(hal_client: hal_client, parsed_json: hash_data),
               curie_resolver: curie_resolver)
    end


    # Returns the URL of the resource this link references.
    # In the case of a templated link, this is the unresolved url template pattern.
    def raw_href
      templated? ? template.pattern : target.href
    end

    def resolved_rel
      curie_resolver.resolve(rel)
    end

    # Returns true for a templated link, false for an ordinary (non-templated) link
    def templated?
      !template.nil?
    end

    # Links with the same href, same rel value, and the same 'templated' value are considered equal
    # Otherwise, they are considered unequal
    def ==(other)
      if other.respond_to?(:raw_href) &&
         other.respond_to?(:resolved_rel) &&
         other.respond_to?(:templated?)
        (raw_href == other.raw_href) &&
          (resolved_rel == other.resolved_rel) &&
          (templated? == other.templated?)
      else
        false
      end
    end
    alias :eql? :==


    # Differing Representations or Addressable::Templates with matching hrefs will get matching hash
    # values, since we are using raw_href and not the objects themselves when computing hash
    def hash
      [resolved_rel, raw_href, templated?].hash
    end

  end
end

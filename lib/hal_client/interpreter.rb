require 'forwardable'
require 'addressable/template'
require 'hal_client/representation'
require 'hal_client/link'
require 'hal_client/curie_resolver'

class HalClient
  # Interprets parsed JSON
  class Interpreter
    extend Forwardable

    # Collection of reserved properties
    # https://tools.ietf.org/html/draft-kelly-json-hal-07#section-4.1
    RESERVED_PROPERTIES = ['_links', '_embedded'].freeze

    # Create a new intepreter
    #
    # parsed_json - `Hash` of the objects in the json
    # hal_client - `HalClient` to use to make requests
    # content_location - `Addressable::URI` of the resource the
    #   parsed json represents (if known)
    # context_url - `Addressable::URI` of the container of the
    #   parsed json, if there is one.
    def initialize(parsed_json,
                   hal_client=HalClient.new,
                   content_location: nil,
                   context_url: content_location)
      (fail InvalidRepresentationError,
            "Invalid HAL representation: #{parsed_json.inspect}") unless
        hashish?(parsed_json)

      @raw = parsed_json
      @hal_client = hal_client
      @content_location = figure_effective_content_location(content_location, context_url)
      @base_url = figure_effective_base_url(context_url)
    end

    # Returns `HalClient::Representation` version of the json provided
    def extract_repr()
      Representation.new(content_location_for_repr, extract_props, extract_links, hal_client)
    end

    # Returns hash of properties from `parsed_json`
    def extract_props()
      raw.reject{|k,_| RESERVED_PROPERTIES.include?(k) }
    end

    def extract_links()
      @links ||= extract_embedded_links +  extract_basic_links
    end

    protected

    attr_reader :raw, :hal_client, :base_url, :content_location

    def content_location_for_repr
      if AnonymousResourceLocator === content_location
        content_location
      else
        content_location
      end
    end

    def uri(uri_ish)
      if AnonymousResourceLocator === uri_ish
        uri_ish

      elsif uri_ish.nil?
        AnonymousResourceLocator.new

      else
        Addressable::URI.parse(uri_ish)
      end
    end

    def figure_effective_content_location(content_location, base_url)
      base_url = uri(base_url)

      if content_location
        base_url + uri(content_location)
      elsif raw_self_url
        base_url + uri(raw_self_url)
      else
        AnonymousResourceLocator.new
      end
    end

    def figure_effective_base_url(base_url)
      if base_url
        uri(base_url)
      else
        content_location
      end
    end

    def raw_self_url
      @raw_self_url ||=
        begin
          self_link_objs = raw
                           .fetch("_links"){{}}
                           .fetch("self"){[]}

          self_link_objs = [self_link_objs] unless Array === self_link_objs

          self_urls = self_link_objs
                      .map{|lo| lo["href"]}
                      .compact
                      .uniq

          (fail InvalidRepresentationError, "too many self links") if self_urls.count > 1

          self_urls.first
        end
    end

    def hashish?(obj)
      obj.respond_to?(:[]) &&
        obj.respond_to?(:map)
    end

    def extract_basic_links
      raw
        .fetch("_links") { Hash.new }
        .flat_map { |rel, target_info|
          build_links(rel, target_info)
        }
        .compact
        .to_set
    end

    def extract_embedded_links
      raw
        .fetch("_embedded") { Hash.new }
        .flat_map { |rel, embedded_json|
           build_embedded_links(rel, embedded_json)
        }
        .compact
        .to_set
    end

    def build_links(rel, target_info)
      arrayify(target_info)
        .map { |info|
          if info["templated"]
            build_templated_link(rel, info)
          else
            build_direct_link(rel, info)
          end
        }
        .compact
    end

    def build_embedded_links(rel, targets_json)
      arrayify(targets_json)
        .map{ |target_json|
          target_repr = Interpreter.new(target_json, hal_client, context_url: content_location).extract_repr

          SimpleLink.new(rel: rel,
                         target: target_repr,
                         curie_resolver: curie_resolver,
                         embedded: true)
        }

    rescue InvalidRepresentationError => e
      MalformedLink.new(rel: rel,
                        msg: "/_embedded/#{jpointer_esc(rel)} is invalid (cause: #{e.message})",
                        curie_resolver: curie_resolver)
    end

    def build_templated_link(rel, info)
      fail(InvalidRepresentationError) unless hashish?(info)

      target_pattern = info.fetch("href") { fail InvalidRepresentationError }
      fq_target_pattern = (base_url + target_pattern)

      TemplatedLink.new(rel: rel,
                        template: Addressable::Template.new(fq_target_pattern),
                        curie_resolver: curie_resolver,
                        hal_client: hal_client)

    rescue InvalidRepresentationError
      MalformedLink.new(rel: rel,
                        msg: "/_links/#{jpointer_esc(rel)} is invalid",
                        curie_resolver: curie_resolver)
    end

    def build_direct_link(rel, info)
      fail InvalidRepresentationError unless hashish?(info)

      target_url = info.fetch("href") { fail InvalidRepresentationError }
      return nil unless target_url
      target_url = base_url + target_url

      target_repr = RepresentationFuture.new(target_url, hal_client)

      SimpleLink.new(rel: rel,
                     target: target_repr,
                     curie_resolver: curie_resolver,
                     embedded: false)

    rescue InvalidRepresentationError
      MalformedLink.new(rel: rel,
                        msg: "/_links/#{jpointer_esc(rel)} is invalid",
                        curie_resolver: curie_resolver)
    end

    def curie_resolver
      @curie_resolver ||= CurieResolver.new(raw.fetch("_links", {}).fetch("curies", []))
    end

    def hashish?(thing)
      thing.kind_of?(Hash) ||
        thing.respond_to?(:fetch) && thing.respond_to?(:key?)
    end

    def arrayify(obj)
      if Array === obj
        obj
      else
        [obj]
      end
    end

    def jpointer_esc(str)
      str.gsub "/", "~1"
    end

  end
end

require "hal_client/version"
require 'http'
require 'multi_json'

# Adapter used to access resources.
class HalClient
  autoload :Representation, 'hal_client/representation'
  autoload :RepresentationSet, 'hal_client/representation_set'
  autoload :CurieResolver, 'hal_client/curie_resolver'
  autoload :LinksSection, 'hal_client/links_section'
  autoload :Collection, 'hal_client/collection'
  autoload :InvalidRepresentationError, 'hal_client/errors'
  autoload :NotACollectionError, 'hal_client/errors'
  autoload :HttpClientError, 'hal_client/errors'

  # Initializes a new client instance
  #
  # options - hash of configuration options
  #   :accept - one or more content types that should be
  #     prepended to the `Accept` header field of each request.
  #   :content_type - a single content type that should be
  #     prepended to the `Content-Type` header field of each request.
  #   :headers - a hash of other headers to send on each request.
  def initialize(options={})
    accept       = options.fetch(:accept, 'application/hal+json')
    content_type = options.fetch(:content_type, 'application/hal+json')
    headers      = options.fetch(:headers, {})

    @headers = {accept: accept, content_type: content_type}.merge(headers)
  end

  # Returns a `Representation` of the resource identified by `url`.
  #
  # url - The URL of the resource of interest.
  # headers - custom header fields to use for this request
  def get(url, headers={})
    interpret_response HTTP.with_headers(get_headers(headers)).get(url)
  end

  # Post a `Representation` or `String` to the resource identified at `url`.
  #
  # url - The URL of the resource of interest.
  # data - a `String` or an object that responds to `#to_hal`
  # headers - custom header fields to use for this request
  def post(url, data, headers={})
    req_body = if data.respond_to? :to_hal
                 data.to_hal
               else
                 data
               end

    interpret_response HTTP.with_headers(post_headers(headers)).post(url, body: req_body)
  end

  protected

  attr_reader :headers

  def interpret_response(resp)
    case resp.status
    when 200...300
      begin
        Representation.new hal_client: self, parsed_json: MultiJson.load(resp.to_s)
      rescue MultiJson::ParseError, InvalidRepresentationError => e
        resp
      end

    when 400...500
      raise HttpClientError.new(nil, resp)

    when 500...600
      raise HttpServerError.new(nil, resp)

    else
      raise HttpError.new(nil, resp)

    end
  end

  # Exclude headers that shouldn't go with a GET
  def get_headers(overrides)
    @cleansed_get_headers ||= headers.dup.tap do |get_headers|
      get_headers.delete(:content_type)
    end

    @cleansed_get_headers.merge overrides
  end

  def post_headers(overrides)
    headers.merge(overrides)
  end

  module EntryPointCovenienceMethods
    # Returns a `Representation` of the resource identified by `url`.
    #
    # url - The URL of the resource of interest.
    # options - set of options to pass to `RestClient#get`
    def get(url, options={})
      default_client.get(url, options)
    end

    # Post a `Representation` or `String` to the resource identified at `url`.
    #
    # url - The URL of the resource of interest.
    # data - a `String` or an object that responds to `#to_hal`
    # options - set of options to pass to `RestClient#get`
    def post(url, data, options={})
      default_client.post(url, data, options)
    end

    protected

    def default_client
      @default_client ||= self.new
    end
  end
  extend EntryPointCovenienceMethods

end

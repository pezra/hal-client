require "hal_client/version"
require 'rest-client'
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
  # options - set of options to pass to `RestClient#get`
  def get(url, options={})
    resp = RestClient.get url, get_options(options)
    Representation.new hal_client: self, parsed_json: MultiJson.load(resp)
  end

  # Post a `Representation` or `String` to the resource identified at `url`.
  #
  # url - The URL of the resource of interest.
  # data - a `String` or an object that responds to `#to_hal`
  # options - set of options to pass to `RestClient#post`
  def post(url, data, options={})
    resp = RestClient.post url, data, post_options(options)

    begin
      Representation.new hal_client: self, parsed_json: MultiJson.load(resp)
    rescue MultiJson::ParseError, InvalidRepresentationError => e
      resp
    end
  end

  protected

  attr_reader :headers

  # Exclude headers that shouldn't go with a GET
  def get_options(overrides)
    @cleansed_get_options ||= headers.dup.tap do |get_headers|
      get_headers.delete(:content_type)
    end

    @cleansed_get_options.merge overrides
  end

  def post_options(overrides)
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

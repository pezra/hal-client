require "hal_client/version"
require 'rest-client'

# Adapter used to access resources.
class HalClient
  autoload :Representation, 'hal_client/representation'
  autoload :RepresentationSet, 'hal_client/representation_set'
  autoload :CurieResolver, 'hal_client/curie_resolver'
  autoload :InvalidRepresentationError, 'hal_client/errors'

  # Initializes a new client instance
  #
  # options - hash of configuration options
  #   :accept - one or more content types that should be
  #     prepended to the `Accept` header field of each request.
  #   :content_type - a single content type that should be
  #     prepended to the `Content-Type` header field of each request.
  def initialize(options={})
    @default_accept = options.fetch(:accept, 'application/hal+json')
    @default_content_type = options.fetch(:content_type, 'application/hal+json')
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

  attr_reader :default_accept, :default_content_type

  def get_options(overrides)
    { accept: default_accept }.merge overrides
  end

  def post_options(overrides)
    {
      accept: default_accept,
      content_type: default_content_type
    }.merge overrides
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

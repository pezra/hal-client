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
  def initialize(options={})
    @default_accept = options.fetch(:accept, 'application/hal+json')
  end

  # Returns a `Representation` of the resource identified by `url`.
  #
  # url - The URL of the resource of interest.
  # options - set of options to pass to `RestClient#get`
  def get(url, options={})
    resp = RestClient.get url, rest_client_options(options)
    Representation.new hal_client: self, parsed_json: MultiJson.load(resp)
  end

  protected

  attr_reader :default_accept

  def rest_client_options(overrides)
    {accept: default_accept}.merge overrides
  end

  module EntryPointCovenienceMethods
    # Returns a `Representation` of the resource identified by `url`.
    #
    # url - The URL of the resource of interest.
    # options - set of options to pass to `RestClient#get`
    def get(url, options={})
      default_client.get(url, options)
    end

    protected

    def default_client
      @default_client ||= self.new
    end
  end
  extend EntryPointCovenienceMethods

end

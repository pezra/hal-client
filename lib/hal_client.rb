require "hal_client/version"
require 'halibut'
require 'halibut/adapter/json'
require 'rest-client'

# Adapter used to access resources.
class HalClient
  autoload :Representation, 'hal_client/representation'
  autoload :RepresentationSet, 'hal_client/representation_set'

  def initialize(options={})
    @default_accept = options.fetch(:accept, 'application/hal+json')
  end

  def get(url, options={})
    resp = RestClient.get url, rest_client_options(options)
    Representation.new self, Halibut::Adapter::JSON.parse(resp)
  end

  protected

  attr_reader :default_accept

  def rest_client_options(overrides)
    {accept: default_accept}.merge overrides
  end
end

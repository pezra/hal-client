require 'hal_client'
require 'forwardable'

class HalClient
  # A representation that will be fetch from the server on
  # demand. Instance of this class are interchangeable with
  # `Representation`s
  class RepresentationFuture < DelegateClass(Representation)
    def initialize(href, hal_client)
      @href = href
      @hal_client = hal_client
    end

    attr_reader :href, :hal_client

    def methods
      self.class.instance_methods
    end

    def __getobj__
      @reified_repr ||= fetch_repr
    end

    protected

    def fetch_repr
      hal_client.get(href)
    end
  end
end
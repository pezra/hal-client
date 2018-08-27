require 'hal_client'
require 'forwardable'

class HalClient
  # A representation that will be fetch from the server on
  # demand. Instance of this class are interchangeable with
  # `Representation`s
  class RepresentationFuture < DelegateClass(Representation)
    # Initialize a new representation future.
    #
    # location - `Addressable::URI` of the resource from which to
    #   fetch a representation.
    # hal_client - the `HalClient` with which to make the request.
    def initialize(location, hal_client)
      @location = location
      @hal_client = hal_client
    end

    # Returns `Addressable::URI` of the resource this represent
    attr_reader :location

    # Returns location of this representation.
    #
    # ---
    #
    # We implement this to prevent premature reification. `href`ing
    # should not cause an HTTP request.
    alias_method :href, :location

    # Returns the `HalClient` used to fetch this represention
    attr_reader :hal_client

    # Returns short string representation of this object.
    #
    # ---
    #
    # We implement this to prevent premature reification. `to_s`ing
    # should not cause an HTTP request.
    def to_s
      "#<HalClient::RepresentationFuture: #{location}>"
    end

    # Returns detailed string representation of this object.
    #
    # ---
    #
    # We implement this to prevent premature reification. `inspect`ing
    # should not cause an HTTP request.
    def inspect
      if reified?
        "#<HalClient::RepresentationFuture #{__getobj__.inspect}>"
      else
        "#<HalClient::RepresentationFuture #{location} (unreified)>"
      end
    end

    # Returns well formatted detailed string representation of this
    # object.
    #
    # ---
    #
    # We implement this to prevent premature
    # reification. `pretty_print`ing should not cause an HTTP request.
    def pretty_print(pp)
      pp.text "#<HalClient::RepresentationFuture"

      if reified?
        pp.newline
        pp.text "__getobj__="
        pp.pp(__getobj__)
        pp.breakable
      else
        pp.breakable
        pp.text "#{location} (unreified)"
      end

      pp.breakable(" ")
      pp.text(">")
    end

    def methods
      self.class.instance_methods
    end

    def reified?
      !@reified_repr.nil?
    end

    def __getobj__
      @reified_repr ||= fetch_repr
    end

    protected

    def fetch_repr
      hal_client.get(location)
    end
  end
end
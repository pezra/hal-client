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

    # Returns short string representation of this object.
    #
    # ---
    #
    # We implement this to prevent premature reification. `to_s`ing
    # should not cause an HTTP request.
    def to_s
      "#<HalClient::RepresentationFuture: #{href}>"
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
        "#<HalClient::RepresentationFuture #{href} (unreified)>"
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
        pp.text "#{href} (unreified)"
      end

      pp.breakable(" ")
      pp.text(">")
    end

    attr_reader :href, :hal_client

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
      hal_client.get(href)
    end
  end
end
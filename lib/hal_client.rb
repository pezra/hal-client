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
  autoload :HttpError, 'hal_client/errors'
  autoload :HttpClientError, 'hal_client/errors'
  autoload :HttpServerError, 'hal_client/errors'

  autoload :RepresentationEditor, 'hal_client/representation_editor'

  # Initializes a new client instance
  #
  # options - hash of configuration options
  #   :accept - one or more content types that should be
  #     prepended to the `Accept` header field of each request.
  #   :content_type - a single content type that should be
  #     prepended to the `Content-Type` header field of each request.
  #   :authorization - a `#call`able which takes the url being
  #     requested and returns the authorization header value to use
  #     for the request or a string which will always be the value of
  #     the authorization header
  #   :headers - a hash of other headers to send on each request.
  #   :base_client - An HTTP::Client object to use.
  def initialize(options={})
    @default_message_request_headers = HTTP::Headers.new
    @default_entity_request_headers = HTTP::Headers.new
    @auth_helper = as_callable(options.fetch(:authorization, NullAuthHelper))
    @base_client ||= options[:base_client]

    default_message_request_headers.set('Accept', options[:accept]) if
      options[:accept]
    # Explicit accept option has precedence over accepts in the
    # headers option.

    options.fetch(:headers, {}).each do |name, value|
      if entity_header_field? name
        default_entity_request_headers.add(name, value)
      else
        default_message_request_headers.add(name, value)
      end
    end

    default_entity_request_headers.set('Content-Type', options[:content_type]) if
      options[:content_type]
    # Explicit content_content options has precedence over content
    # type in the headers option.

    default_entity_request_headers.set('Content-Type', 'application/hal+json') unless
      default_entity_request_headers['Content-Type']
    # We always want a content type. If the user doesn't explicitly
    # specify one we provide a default.

    accept_values = Array(default_message_request_headers.get('Accept')) +
      ['application/hal+json;q=0']
    default_message_request_headers.set('Accept', accept_values.join(", "))
    # We can work with HAL so provide a back stop accept.
  end

  # Returns a `Representation` of the resource identified by `url`.
  #
  # url - The URL of the resource of interest.
  # headers - custom header fields to use for this request
  def get(url, headers={})
    headers = auth_headers(url).merge(headers)
    interpret_response client_for_get(override_headers: headers).get(url)

  rescue HttpError => e
    fail e.class.new("GET <#{url}> failed with code #{e.response.status}", e.response)
  end

  class << self
    protected

    def def_unsafe_request(method)
      define_method(method) do |url, data, headers={}|
        headers = auth_headers(url).merge(headers)

        req_body = if data.respond_to? :to_hal
                     data.to_hal
                   else
                     data
                   end

        begin
          interpret_response client_for_post(override_headers: headers)
                              .request(method, url, body: req_body)

        rescue HttpError => e
          fail e.class.new("#{method.to_s.upcase} <#{url}> failed with code #{e.response.status}", e.response)
        end
      end
    end
  end

  # Post a `Representation` or `String` to the resource identified at `url`.
  #
  # url - The URL of the resource of interest.
  # data - a `String` or an object that responds to `#to_hal`
  # headers - custom header fields to use for this request
  def_unsafe_request :post

  # Put a `Representation` or `String` to the resource identified at `url`.
  #
  # url - The URL of the resource of interest.
  # data - a `String` or an object that responds to `#to_hal`
  # headers - custom header fields to use for this request
  def_unsafe_request :put

  # Patch a `Representation` or `String` to the resource identified at `url`.
  #
  # url - The URL of the resource of interest.
  # data - a `String` or an object that responds to `#to_hal`
  # headers - custom header fields to use for this request
  def_unsafe_request :patch

  # Delete a `Representation` or `String` to the resource identified at `url`.
  #
  # url - The URL of the resource of interest.
  # headers - custom header fields to use for this request
  def delete(url, headers={})
    headers = auth_headers(url).merge(headers)

    begin
      interpret_response client_for_post(override_headers: headers)
                          .request(:delete, url)
    rescue HttpError => e
      fail e.class.new("DELETE <#{url}> failed with code #{e.response.status}", e.response)
    end
  end

  class << self
    def delete(url, headers={})
      new.delete(url, headers)
    end
  end

  protected

  attr_reader :headers, :auth_helper

  NullAuthHelper = ->(_url) { nil }

  def as_callable(thing)
    if thing.respond_to?(:call)
      thing
    else
      ->(*_args) { thing }
    end
  end

  def auth_headers(url)
    if h_val = auth_helper.call(url)
      {"Authorization" => h_val}
    else
      {}
    end
  end

  def interpret_response(resp)
    case resp.status
    when 200...300
      location = resp.headers["Location"]

      begin
        Representation.new(hal_client: self, parsed_json: MultiJson.load(resp.to_s),
                           href: location)
      rescue MultiJson::ParseError, InvalidRepresentationError => e
        if location
          # response doesn't have a HAL body but we know what resource
          # was created so we can be helpful.
          Representation.new(hal_client: self, href: location)
        else
          # nothing useful to be done
          resp
        end
      end

    when 400...500
      raise HttpClientError.new(nil, resp)

    when 500...600
      raise HttpServerError.new(nil, resp)

    else
      raise HttpError.new(nil, resp)

    end
  end

  # Returns the HTTP client to be used to make get requests.
  #
  # options
  #   :override_headers -
  def client_for_get(options={})
    override_headers = options[:override_headers]

    if !override_headers
      @client_for_get ||= base_client.with_headers(default_message_request_headers)
    else
      client_for_get.with_headers(override_headers)
    end
  end

  # Returns the HTTP client to be used to make post requests.
  #
  # options
  #   :override_headers -
  def client_for_post(options={})
    override_headers = options[:override_headers]

    if !override_headers
      @client_for_post ||=
        base_client.with_headers(default_entity_and_message_request_headers)
    else
      client_for_post.with_headers(override_headers)
    end
  end

  # Returns an HTTP client.
  def base_client
    @base_client ||= HTTP::Client.new(follow: true)
  end

  attr_reader :default_entity_request_headers, :default_message_request_headers

  def default_entity_and_message_request_headers
    @default_entity_and_message_request_headers ||=
      default_message_request_headers.merge(default_entity_request_headers)
  end

  def default_entity_request_headers
    @default_entity_request_headers
  end

  def entity_header_field?(field_name)
    [:content_type, /^content-type$/i].any?{|pat| pat === field_name}
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

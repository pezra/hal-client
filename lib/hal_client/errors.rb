class HalClient
  # The representation is not a valid HAL document.
  InvalidRepresentationError = Class.new(StandardError)

  # The representation is not a HAL collection
  NotACollectionError = Class.new(StandardError)

  # Server responded with a non-200 status code
  class HttpError < StandardError
    def initialize(message, response)
      @response = response
      super(message)
    end

    attr_reader :response
  end

  # Server response with a 4xx status code
  HttpClientError = Class.new(HttpError)

  # Server responded with a 5xx status code
  HttpServerError = Class.new(HttpError)

  TimeoutError = Class.new(StandardError)
end
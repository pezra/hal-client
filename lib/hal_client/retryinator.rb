require 'hal_client/null_logger'

class HalClient

  # Retries http requests that meet certain conditions -- we want to retry if we got a 500 level
  # (server) error but not if we got a 400 level (client) error. We want to retry if we rescue an
  # HttpError (likely a network issue) but not more general exceptions that likely indicate another
  # problem that should be surfaced.

  # Example usage:
  # Retryinator.call { fetch_http_response }
  class Retryinator

    attr_reader :max_tries, :interval, :logger

    DEFAULT_MAX_TRIES = 3
    DEFAULT_INTERVAL = 1

    def initialize(options={})
      @max_tries = options.fetch(:max_tries, DEFAULT_MAX_TRIES)
      @interval = options.fetch(:interval, DEFAULT_INTERVAL)
      @logger = options.fetch(:logger, HalClient::NullLogger.new)
    end

    def call(&block)
      current_try = 1

      loop do
        begin
          result = yield block

          if server_error?(result.code)
            logger.warn "Received a #{result.code} response with body:\n#{result.body}"
            return result if current_try >= max_tries
          else
            return result
          end
        rescue HttpError => e
          logger.warn "Encountered an HttpError: #{e.message}"
          raise e if current_try >= max_tries
        end

        logger.warn "Failed attempt #{current_try} of #{max_tries}. " +
                      "Waiting #{interval} seconds before retrying"

        current_try += 1
        sleep interval
      end
    end

    def server_error?(status_code)
      500 <= status_code && status_code < 600
    end
  end
end

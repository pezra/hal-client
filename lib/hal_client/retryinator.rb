require 'hal_client/null_logger'

class HalClient
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

          if result.status.server_error?
            logger.debug "Received a #{result.code} response with body:\n#{result.body}"
            return result if current_try >= max_tries
          else
            return result
          end
        rescue HttpError => e
          logger.debug "Encountered an HttpError: #{e.message}"
          raise e if current_try >= max_tries
        end

        logger.debug "Failed attempt #{current_try}"
        current_try += 1
        sleep interval
      end
    end
  end
end

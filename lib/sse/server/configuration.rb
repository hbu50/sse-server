require 'connection_pool'

module Sse
  module Server
    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration)
      self.configuration.redis_pool
    end

    class Configuration
      attr_accessor \
        :logger,
        :connection_manager,
        :namespace,
        :authorize_lambda,
        :subscribe_lambda,
        :unsubscribe_lambda,
        :redis_uri,
        :redis_connection_pool

      def initialize
        @redis_connection_pool=nil
        @authorize_lambda=lambda{|request, channel|
          return true
        }
        @subscribe_lambda=lambda{|request|
          return true
        }
        @unsubscribe_lambda=lambda{|request|
          return true
        }
      end

      def redis_pool
        return @redis_connection_pool if @redis_connection_pool
        return @redis_connection_pool = ConnectionPool.new(size: 10, timeout: 5) {
          Redis.new(url: @redis_uri, reconnect_attempts: 100)
        }
      end
    end
  end
end

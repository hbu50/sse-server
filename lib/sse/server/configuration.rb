module Sse
  module Server
    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end

    class Configuration
      attr_accessor \
        :logger,
        :connection_manager,
        :namespace,
        :authorize_lambda,
        :redis_uri

      def initialize
        @authorize_lambda=lambda{|request, channel|
          return true
        }
      end
    end
  end
end

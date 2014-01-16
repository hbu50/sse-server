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
        :namespace

      def initialize
      end
    end
  end
end

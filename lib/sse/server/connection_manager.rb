require 'sse/server/redis_channel'
require 'sse/server/configuration'

module Sse
  module Server
    class ConnectionManager
      attr_accessor \
        :logger,
        :channels
      def initialize(logger)
        @channels={}
        @logger=logger
        @logger.debug("Initialized ConnectionManager")
      end

      def subscribe(connection, channel, request)
        if @channels[channel].nil?
          @channels[channel]={redis: nil, clients: []}
          @channels[channel][:redis]=RedisChannel.new(channel,self)
          @channels[channel][:redis].start
        end
        Sse::Server.configuration.subscribe_lambda.call(request)
        
        @channels[channel][:clients] << connection
        @logger.info("Subscribtion To Channel #{channel}. Total(#{@channels[channel][:clients].count})")
      end

      def unsubscribe(connection, channel,request)
        unless @channels[channel].nil?
          @channels[channel][:clients].delete(connection)
          @logger.info("Unsubscribtion from Channel #{channel}. Total(#{@channels[channel][:clients].count})")
          if @channels[channel][:clients].count==0
            #stop and remove this RedisChannel
            @channels[channel][:redis].kill
            @channels.delete(channel)
            @logger.info("Redis Channel Killed(#{channel}).")
          end
          Sse::Server.configuration.unsubscribe_lambda.call(request)
        end
      end

      def connection_of_channel(channel)
        unless @channels[channel].nil?
          return @channels[channel][:clients]
        end
        return []
      end
    end
  end
end

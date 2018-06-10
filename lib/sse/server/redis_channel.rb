require 'redis'
require 'json'

module Sse
  module Server
    class << self
      def ignore_exception
        begin
          yield
        rescue => e
          Sse::Server.configuration.logger.error "Ignored Exception: #{e.message}"
        end
      end
      def pack_as_sse(id, event, data)
        output=""
        output << "id:#{id}\n" if id
        output << "event:#{event}\n" if event
        output << "data: #{data.to_json}" + "\r\n\n"
        return  output
      end
      def message_to_sse(str)
        data=JSON.load(str)
        return pack_as_sse(data["_timestamp"],nil, data)
      end
    end

    class RedisChannel
      # include Celluloid

      attr_accessor \
        :channel,
        :manager,
        :thread

      def initialize(channel,manager)
        @channel=channel
        @manager=manager
        @thread=nil
      end

      def start
        @thread=Thread.new{
          @redis=Redis.new(url: Sse::Server.configuration.redis_uri)
          @manager.logger.warn("New RedisChannel Started Listening On #{@channel}.")
          begin
            @redis.subscribe(@channel) do |on|
              on.subscribe do |channel, subscriptions|
                @manager.logger.warn("Redis Subscribed #{@channel}")
                # publish the updates to interested parties
                Sse::Server.configuration.redis_pool.with do |redis|
                  redis.publish('hs-sse:.internal/pubsub', @channel)
                end
              end

              on.message do |channel, message|
                @manager.logger.debug("RedisChannel(#{channel}) Recived Message(#{message})")
                Sse::Server.ignore_exception {
                  connections=@manager.connection_of_channel(@channel)
                  @manager.logger.info("Send Message to #{connections.count} subscriber.")
                  connections.each do |connection|
                    connection << Sse::Server.message_to_sse(message)
                  end
                }
              end

              on.unsubscribe do |channel, subscriptions|
              end
            end
          rescue Redis::BaseConnectionError => error
            @manager.logger.error("RedisChannel Error On Redis Connection. Channel: #{@channel}")
            sleep 1
            retry
          rescue JSON::ParserError => error
            # how to say just ignore and continue
            @manager.logger.error("Error Parsing JSON.")
          ensure

          end
        }
      end

      def kill
        @redis.disconnect!
        @thread.kill if @thread
        # publish the updates to interested parties
        Sse::Server.configuration.redis_pool.with do |redis|
          redis.publish('hs-sse:.internal/pubsub', @channel)
        end
      end
    end
  end
end

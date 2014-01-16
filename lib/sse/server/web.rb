require 'sinatra/base'
require 'redis'
module Sse
  module Server

    class Web < ::Sinatra::Base

      get 'status', provides: 'application/json' do

      end
      get '/c/*' ,provides: 'text/event-stream' do
        Sse::Server.configuration.logger.error("New event-stream Request. Channel: #{params[:splat].first}")

        # @authorize_block(request,channel)


        channel=Sse::Server.configuration.namespace+":"+params[:splat].first
        last_event_id=request.env['HTTP_LAST_EVENT_ID']

        Sse::Server.configuration.logger.debug "LAST-EVENT-ID IS #{last_event_id}, Channel is #{channel}"

        stream(:keep_open) do |connection|
          if last_event_id
            #check redis
            redis= Redis.connect
            members=redis.zrangebyscore(channel,last_event_id,last_event_id)
            if members.count > 0
              members=redis.zrangebyscore(channel,last_event_id,'+inf')
              Sse::Server.configuration.logger.info("Send Old events(count: #{members.count}).")
              members.each do |m|
                connection << message_to_sse(m)
              end
            else# client is outdated
              Sse::Server.configuration.logger.info("Client Outdated from #{last_event_id}.")
              connection << pack_as_sse(nil, 'control', {type: "error", error: "outdated"})
              connection.close
            end
          end
          EventMachine::PeriodicTimer.new(25) { connection << ":\n" } # required, otherwise the connection is closed in 30-60 sec
          
          Sse::Server.configuration.connection_manager.subscribe(connection,channel)
          connection.callback {
            Sse::Server.configuration.logger.error("event-stream client disconnected. Channel: #{params[:splat].first}")
            Sse::Server.configuration.connection_manager.unsubscribe(connection,channel)
          }
        end
      end

      private
    end
  end
end

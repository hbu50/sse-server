require 'sinatra/base'
require 'redis'
module Sse
  module Server

    class Web < ::Sinatra::Base

      get 'status', provides: 'application/json' do

      end
      get '/c/*' ,provides: 'text/event-stream' do
        nnel=params[:splat].first
        Sse::Server.configuration.logger.error("New event-stream Request. Channel: #{nnel}")

        authorized=Sse::Server.configuration.authorize_lambda.call(request,nnel)
        if authorized==false
          halt 401, 'unauthorized :-x'
        end

        
        channel=Sse::Server.configuration.namespace+":"+nnel
        last_event_id=request.env['HTTP_LAST_EVENT_ID']

        Sse::Server.configuration.logger.debug "LAST-EVENT-ID IS #{last_event_id}, Channel is #{channel}"

        headers 'Access-Control-Allow-Origin'=> '*'

        stream(:keep_open) do |connection|
          begin
            if last_event_id
              #check redis
              redis= Redis.connect(url: Sse::Server.configuration.redis_uri)
              members=redis.zrangebyscore(channel,last_event_id,last_event_id)
              if members.count > 0
                members=redis.zrangebyscore(channel,last_event_id,'+inf')
                Sse::Server.configuration.logger.info("Send Old events(count: #{members.count}).")
                members.each do |m|
                  connection << Sse::Server.message_to_sse(m)
                end
              else# client is outdated
                Sse::Server.configuration.logger.info("Client Outdated from #{last_event_id}.")
                connection << Sse::Server.pack_as_sse(nil, 'control', {type: "error", error: "outdated"})
                connection.close
              end
              redis.quit
            end
            EventMachine::PeriodicTimer.new(25) { connection << ":\n" } # required, otherwise the connection is closed in 30-60 sec
            
            Sse::Server.configuration.connection_manager.subscribe(connection,channel,request)
            connection.callback {
              Sse::Server.configuration.logger.error("event-stream client disconnected. Channel: #{nnel}")
              Sse::Server.configuration.connection_manager.unsubscribe(connection,channel,request)
            }
          rescue ::Exception => e
            Sse::Server.configuration.logger.fatal("Exception in stream: ")
            Sse::Server.configuration.logger.fatal(e.backtrace)
            connection.close
          end
        end
      end

      private
    end
  end
end

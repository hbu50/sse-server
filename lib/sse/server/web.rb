require 'sinatra/base'
require 'redis'
require 'securerandom'
require 'json'
require 'sse/server/web_helper'

module Sse
  module Server

    class Web < ::Sinatra::Base

      get '/status', provides: 'application/json' do
        {
          sse: Sse::Server.configuration.connection_manager.stats,
          redis: Sse::Server::WebHelper.redis_info

        }.to_json
      end

      get '/info/subscribers', provides: 'application/json' do
        nnel=params[:channel]

        authorize=Sse::Server.configuration.authorize_lambda.call(request,nnel)
        unless authorize
           halt 401, 'unauthorized :-x'
        end
        channel=Sse::Server.configuration.namespace+":"+nnel

        subscribers={}
        Sse::Server.configuration.redis_pool.with do |redis|
          subscribers=redis.hgetall(channel+'-subscribers')
        end

        subscribers=subscribers.values.map{|s| JSON.parse(s)}
        subscribers.reject!{|payload| Time.now.to_i - payload['_timestamp'] > 40}

        headers 'Access-Control-Allow-Origin'=> '*'
        headers 'Access-Control-Request-Method'=> 'GET'

        subscribers.map{|s| s['data']}.to_json
      end
      get '/c/*' ,provides: 'text/event-stream' do
        nnel=params[:splat].first
        Sse::Server.configuration.logger.error("New event-stream Request. Channel: #{nnel}")

        payload=Sse::Server.configuration.authorize_lambda.call(request,nnel)
        unless payload
           halt 401, 'unauthorized :-x'
        end
        payload[:uid]=SecureRandom.uuid

        channel=Sse::Server.configuration.namespace+":"+nnel
        last_event_id=request.env['HTTP_LAST_EVENT_ID']

        Sse::Server.configuration.logger.debug "LAST-EVENT-ID IS #{last_event_id}, Channel is #{channel}"

        headers 'Access-Control-Allow-Origin'=> '*'

        stream(:keep_open) do |connection|
          begin
            if last_event_id
              #check redis
              Sse::Server.configuration.redis_pool.with do |redis|
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
              end
            end
            timer = EventMachine::PeriodicTimer.new(25) do
              connection << ":\n"
              Sse::Server.configuration.connection_manager.save_payload(channel,payload)
              # required, otherwise the connection is closed in 30-60 sec
            end
            Sse::Server.configuration.connection_manager.subscribe(connection,channel,request,payload)
            connection.callback {
              timer.cancel
              Sse::Server.configuration.logger.error("event-stream client disconnected. Channel: #{nnel}")
              Sse::Server.configuration.connection_manager.unsubscribe(connection,channel,request,payload)
            }
          rescue => e
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

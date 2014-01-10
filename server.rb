require 'celluloid'
require 'redis'
require 'sinatra/base'
require 'json'

def ignore_exception
   begin
     yield  
   rescue Exception
  end
end

def pack_as_sse(id, data)
  return "id:#{id}\n" + "data: #{data.to_json}" + "\r\n\n"
end
def message_to_sse(str)
  data=JSON.load(str)
  puts "DATA IS " + data.inspect
  return pack_as_sse(data["updated_at"], data)
end

class ConnectionManager
  def initialize
    @channels={}
  end

  def subscribe(connection, channel)
    if @channels[channel].nil?
      @channels[channel]={redis: nil, clients: []}
      @channels[channel][:redis]=RedisChannel.new(channel,self)
      @channels[channel][:redis].async.start
    end
    @channels[channel][:clients] << connection
  end

  def unsubscribe(connection, channel)
    unless @channels[channel].nil?
      @channels[channel][:clients].delete(connection)

      if @channels[channel][:clients].count==0
        #stop and remove this RedisChannel
        # @channels[channel][:redis].terminate
      end
    end
  end

  def connection_of_channel(channel)
    unless @channels[channel].nil?
      return @channels[channel][:clients]
    end
    return []
  end
end

class RedisChannel
  include Celluloid

  @channel=nil
  
  def initialize(channel,manager)
    @channel=channel
    @manager=manager
  end

  def start
    @redis=Redis.connect
    begin
      @redis.subscribe(@channel) do |on|
        on.subscribe do |channel, subscriptions|
        end

        on.message do |channel, message|
          ignore_exception {
            connections=@manager.connection_of_channel(@channel)
            connections.each do |connection|
              connection << message_to_sse(message)
            end
          }
        end

        on.unsubscribe do |channel, subscriptions|
        end
      end
    rescue Redis::BaseConnectionError => error
      sleep 1
      retry
    rescue JSON::ParserError => error
      # how to say just ignore and continue
    end
  end
  
end



CONNECTION_MANAGER=ConnectionManager.new

class SseWeb < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  get '/ssec/*' ,provides: 'text/event-stream' do
    channel=ENV["SSE_REDIS_NAMESPACE"]+params[:splat].first
    last_event_id=request.env['HTTP_LAST_EVENT_ID']

    # logger.info "#{request.url}"
    # logger.info request.inspect

    logger.info "New #{channel} Subscriber."
    logger.info "LAST-EVENT-ID IS #{last_event_id}"
    logger.info request.env
    

    

    stream(:keep_open) do |connection|
      if last_event_id
        #check redis 
        redis= Redis.connect
        members=redis.zrangebyscore(channel,last_event_id,"+inf")
        logger.info "MEMBERS ARE "+members.inspect
        members.each do |m|
          connection << message_to_sse(m)
        end
      end
    
      EventMachine::PeriodicTimer.new(25) { connection << ":\n" } # required, otherwise the connection is closed in 30-60 sec
      
      CONNECTION_MANAGER.subscribe(connection,channel)
      connection.callback {
        CONNECTION_MANAGER.unsubscribe(connection,channel)
        logger.info "Someone Unsubscribed #{channel}"
      }
    end

  end

  private
  def send_sse_json(id, data)
    "id: #{id}\n" +
    "data: #{data.to_json}" +
    "\r\n\n"
  end

  #auth
  def authorize!
    halt 401, 'UnAuthenticated'
  end  

  # start the server if ruby file executed directly
  run! if app_file == $0
end

module Sse::Server::WebHelper
  FAKE_INFO = {
    "redis_version" => "9.9.9",
    "uptime_in_days" => "9999",
    "connected_clients" => "9999",
    "used_memory_human" => "9P",
    "used_memory_peak_human" => "9P"
  }.freeze

  REDIS_KEYS = %w(redis_version uptime_in_days connected_clients used_memory_human used_memory_peak_human).freeze

  def self.redis_all_info
    Sse::Server.configuration.redis_pool.with do |conn|
      # redis do |conn|
        begin
          # admin commands can't go through redis-namespace starting
          # in redis-namespace 2.0
          if conn.respond_to?(:namespace)
            conn.redis.info
          else
            conn.info
          end
        rescue Redis::CommandError => ex
          #2850 return fake version when INFO command has (probably) been renamed
          raise unless ex.message =~ /unknown command/
          FAKE_INFO
        end
      end
    # end
  end

  def self.redis_info
    redis_all_info.select { |k, v| REDIS_KEYS.include? k }
  end

end


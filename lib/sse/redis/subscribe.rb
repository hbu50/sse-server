class Redis
  class SubscribedClient
    def disconnect
      @client.disconnect
    end
  end
end

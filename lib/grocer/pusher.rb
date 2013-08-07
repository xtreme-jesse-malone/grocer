module Grocer
  class Pusher
    def initialize(connection)
      @connection = connection
    end

    def push(notification)
      @connection.write(notification.to_bytes)
    end

    # close pusher connection
    # NOTE: connection will wait [timout] seconds
    # for any possible error response from apple.
    def close(timeout=2)
    	@connection.close(timeout)
    end
  end
end

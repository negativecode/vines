# encoding: UTF-8

module Vines
  class Stream
    class Http
      # HttpStates is a cache of HttpState objects for transient HTTP
      # connections. The cache is monitored for expired client connections.
      class HttpStates
        include Vines::Log

        def initialize
          @states = {}
          start_timer
        end

        def []=(sid, state)
          @states[sid] = state
        end

        def [](sid)
          @states[sid]
        end

        def connected_http_clients
          @states
        end

        def delete
          @states
        end

        private

        # Check for expired clients to cleanup every 5 seconds.
        def start_timer
          @timer ||= EventMachine::PeriodicTimer.new(5) { cleanup }
        end

        # Remove cached information for all expired connections. An expired
        # HTTP client is one that has no queued requests and has had no activity
        # for over 60 seconds.
        def cleanup
          expired = @states.select {|sid, state| state.expired? }
          expired.each do |sid, http_state|
            @states.delete(sid)
            log.debug("Removed expired HTTP client #{sid}")
          end
        rescue Exception => e
          log.error("HTTP cleanup failed: #{e}")
        end
      end
    end
  end
end
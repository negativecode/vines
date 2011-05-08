# encoding: UTF-8

module Vines
  class Stream
    class Http
      class HttpStates
        include Vines::Log

        def start_timer
          @timer ||= EventMachine::PeriodicTimer.new(5) { cleanup }
        end

        def initialize
          @http_states = {}
          start_timer
        end

        def cleanup
          # An expired HTTP client is one that has no queued requests
          # and has no activity in more than 60 seconds
          expired.each do |sid, http_state|
            @http_states.delete(sid)
            log.debug("Removed expired HTTP client #{sid}")
          end
        rescue Exception => e
          log.error("Failed to cleanup HTTP connections: #{e}")
        end

        def []=(sid, http_state)
          @http_states[sid] = http_state
        end

        def [](sid)
          @http_states[sid]
        end

        def connected_http_clients
          @http_states
        end

        def delete
          @http_states
        end

        private

        def expired
          @http_states.select {|sid, http_state| http_state.expired? }
        end
      end
    end
  end
end
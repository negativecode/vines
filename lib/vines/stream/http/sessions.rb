# encoding: UTF-8

module Vines
  class Stream
    class Http
      # Sessions is a cache of Http::Session objects for transient HTTP
      # connections. The cache is monitored for expired client connections.
      class Sessions
        include Vines::Log

        @@instance = nil
        def self.instance
          @@instance ||= self.new
        end

        def self.[](sid)
          instance[sid]
        end

        def self.[]=(sid, session)
          instance[sid] = session
        end

        def self.delete(sid)
          instance.delete(sid)
        end

        def initialize
          @sessions = {}
          start_timer
        end

        def []=(sid, session)
          @sessions[sid] = session
        end

        def [](sid)
          @sessions[sid]
        end

        def delete(sid)
          @sessions.delete(sid)
        end

        private

        # Check for expired clients to cleanup every second.
        def start_timer
          @timer ||= EventMachine::PeriodicTimer.new(1) { cleanup }
        end

        # Remove cached information for all expired connections. An expired
        # HTTP client is one that has no queued requests and has had no activity
        # for over 20 seconds.
        def cleanup
          @sessions.each_value do |session|
            session.close if session.expired?
          end
        rescue => e
          log.error("Expired session cleanup failed: #{e}")
        end
      end
    end
  end
end
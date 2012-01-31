# encoding: UTF-8

module Vines
  class Cluster
    # Create and cache a redis database connection.
    class Connection
      attr_accessor :host, :port, :database, :password

      def initialize
        @redis, @host, @port, @database, @password = nil, nil, nil, nil, nil
      end

      # Return a shared redis connection.
      def connect
        @redis ||= create
      end

      # Return a new redis connection.
      def create
        conn = EM::Hiredis::Client.new(@host, @port, @password, @database)
        conn.connect
        conn
      end
    end
  end
end

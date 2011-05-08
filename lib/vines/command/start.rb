# encoding: UTF-8

module Vines
  module Command
    class Start
      def run(opts)
        raise 'vines [--pid FILE] start' unless opts[:args].size == 0
        require opts[:config]
        server = XmppServer.new(Config.instance)
        daemonize(opts) if opts[:daemonize]
        server.start
      end

      private

      def daemonize(opts)
        daemon = Daemon.new(:pid => opts[:pid], :stdout => opts[:log],
          :stderr => opts[:log])
        if daemon.running?
          raise "Vines is running as process #{daemon.pid}"
        else
          puts "Vines has started"
          daemon.start
        end
      end
    end
  end
end
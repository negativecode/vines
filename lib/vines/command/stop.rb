# encoding: UTF-8

module Vines
  module Command
    class Stop
      def run(opts)
        raise 'vines [--pid FILE] stop' unless opts[:args].size == 0
        daemon = Daemon.new(:pid => opts[:pid])
        if daemon.running?
          daemon.stop
          puts 'Vines has been shutdown'
        else
          puts 'Vines is not running'
        end
      end
    end
  end
end
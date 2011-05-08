# encoding: UTF-8

module Vines

  # The main starting point for the XMPP server process. Starts the
  # EventMachine processing loop and registers the XMPP protocol handler
  # with the ports defined in the server configuration file.
  class XmppServer
    include Vines::Log

    def initialize(config)
      @config = config
    end

    def start
      log.info('XMPP server started')
      at_exit { log.fatal('XMPP server stopped') }
      EM.epoll
      EM.kqueue
      EM.run do
        @config.ports.each {|port| port.start }
      end
    end
  end
end

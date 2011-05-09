# encoding: UTF-8

module Vines
  class Stream
    class Http < Client
      include Thin
      include Vines::Log

      attr_accessor :last_broadcast_presence

      def initialize(config)
        @config = config
        @domain = nil
        @requested_roster = false
        @available = false
        @unbound = false
        @last_broadcast_presence = nil
        @request = Thin::Request.new
        @@http_states ||= HttpStates.new
        @state = Auth.new(self)
      end

      def domain
        @http_state.domain
      end

      def user
        @http_state.user
      end

      def user=(user)
        @http_state.user = user
      end

      def receive_data(data)
        #TODO: make sure we add max stanza size enforcement
        if @request.parse(data)
          process_http_request(@request)
          @request = Thin::Request.new
        end
      rescue InvalidRequest => e
        error(StreamErrors::NotWellFormed.new)
      end

      # Alias the Stream#write method before overriding it so we can call
      # it later from an HttpState instance.
      alias :stream_write :write

      # Override Stream#write to queue stanzas rather than immediately writing
      # to the stream. Stanza responses must be paired with a queued request.
      def write(data)
        @http_state.write(data)
      end

      def setup_new_client(rid, domain)
        sid = Kit.uuid
        log.info("Setting up a new client SID: #{sid} for RID: #{rid}.")
        @http_state = HttpState.new(self, sid, rid, domain)
        @@http_states[sid] = @http_state
      end

      def unbind
        #router.delete(@http_state)
        log.info("HTTP Stream disconnected:\tfrom=#{@remote_addr}\tto=#{@local_addr}")
        log.info("Streams connected: #{router.size}")
      end

      def process_http_request(request)
        if request.body.string.empty?
          #Respond to proxy servers' status pings
          log.info("A status request has been received.")
          send_data("Online")
          close_connection_after_writing
          return
        end
        body = Nokogiri::XML(request.body.string).root
        body.namespace = nil
        #TODO: Confirm this is a valid body stanza.
        # If it isn't a body, return proxy ping result

        if body['sid']
          @http_state = @@http_states[body['sid']]
          unless @http_state
            log.info("Client was not found #{body['sid']}")
            send_bosh_error
            return
          end
          @domain = @http_state.domain
          @user = @http_state.user
          @http_state.request(body['rid'])
          if body['restart']
            @http_state.handle_restart
            router << @http_state
            @state = Bind.new(self)
          end

          body.elements.each do |node|
            @nodes.push(Nokogiri::XML(node.to_s.sub(' xmlns="jabber:client"', '')).root)
          end
        else
          setup_new_client(body['rid'], body['to'])
        end
      end

      private

      def send_bosh_error
        body = '<body type="terminate" condition="remote-connection-failed" xmlns="http://jabber.org/protocol/httpbind"/>'
        header = [
          "HTTP/1.1 404 OK",
          "Content-Type: text/xml; charset=utf-8",
          "Content-Length: #{body.bytesize}"
        ].join("\r\n")
        stream_write([header, body].join("\r\n\r\n"))
      end
    end
  end
end

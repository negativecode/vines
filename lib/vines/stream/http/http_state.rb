# encoding: UTF-8

module Vines
  class Stream
    class Http
      class HttpState
        include Nokogiri::XML

        attr_reader :domain
        attr_accessor :last_broadcast_presence, :expiration, :domain
        attr_accessor :last_activity, :queued_stanzas, :queued_requests, :user

        def initialize(stream, sid, rid, domain=nil)
          @stream, @sid, @domain = stream, sid, domain
          @last_activity = Time.now
          @state = Stream::Client::Start.new(self)
          @queued_stanzas = []
          @queued_requests = []
          @expiration = 65
          @pinged = false
          create_session(rid, sid)
        end

        def method_missing(method, *args, &block)
          @stream.send(method, *args, &block)
        end

        def send_response(data, sid, rid)
          doc = Document.new
          body = doc.create_element('body',
            'rid' => rid,
            'sid' => sid,
            'xmlns' => NAMESPACES[:http_bind]) do |node|
              node.inner_html = data
            end
          reply(body)
        end

        def expired?
          cleanup_requests
          (Time.now - @last_activity > @expiration) && @queued_requests.empty?
        end

        def cleanup_requests
          timed_out_requests.each do |request|
            log.debug("Clearing out #{request.rid}")
            send_response("", @sid, request.rid)
            @queued_requests.delete(request)
          end
        end

        def ping
          log.debug("Pinging #{self}. Request queue: #{@queued_requests}")
          @last_activity = Time.now
          write("")
          @pinged = true
        end

        def pinged?
          @pinged
        end

        def create_session(rid, sid)
          doc = Document.new
          node = doc.create_element('body',
            'accept'     => 'deflate,gzip',
            'ack'        => rid,
            'charsets'   => 'UTF-8',
            'from'       => domain, 
            'hold'       => '1',
            'inactivity' => '30',
            'maxpause'   => '120',
            'polling'    => '5',
            'requests'   => '2',
            'sid'        => sid,
            'ver'        => '1.6',
            'wait'       => '60',
            'xmlns'      => 'http://jabber.org/protocol/httpbind')

          node << doc.create_element('features', 'xmlns' => 'jabber:client') do |el|
            el << doc.create_element('mechanisms') do |parent|
              parent.default_namespace = NAMESPACES[:sasl]
              mechanisms.each {|name| parent << doc.create_element('mechanism', name) }
            end
          end
          reply(node)
        end

        def request(rid)
          @pinged = false
          @last_activity = Time.now
          if @queued_stanzas.size > 0
            send_response(@queued_stanzas.join(" "), @sid, rid)
            @queued_stanzas.clear
          else
            @queued_requests << HttpRequest.new(rid)
          end
        end

        def write(node)
          request = @queued_requests.shift
          unless request.nil?
            send_response(node.to_s, @sid, request.rid)
          else
            @queued_stanzas << node.to_s
          end
        end

        def timed_out_requests
          @queued_requests.select {|request| request.timed_out? }
        end

        def mechanisms
          ['EXTERNAL', 'PLAIN']
        end

        def handle_restart
          doc = Document.new
          node = doc.create_element('body',
            'xmlns' => NAMESPACES[:http_bind],
            'xmlns:stream' => NAMESPACES[:stream])
          node << doc.create_element('stream:features') do |features|
            features << doc.create_element('bind', 'xmlns' => NAMESPACES[:bind])
          end
          @available = true
          reply(node)
        end

        private

        # Send an HTTP 200 OK response wrapping the XMPP node content back
        # to the client.
        def reply(node)
          body = node.to_s
          header = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/xml; charset=utf-8",
            "Content-Length: #{body.bytesize}"
          ].join("\r\n")

          @stream.stream_write([header, body].join("\r\n\r\n"))
        end
      end
    end
  end
end
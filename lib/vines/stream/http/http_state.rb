# encoding: UTF-8

module Vines
  class Stream
    class Http
      class HttpState
        include Nokogiri::XML

        attr_reader :domain
        attr_accessor :domain, :last_broadcast_presence, :user

        def initialize(stream, sid, rid, domain)
          @stream, @sid, @domain = stream, sid, domain
          @last_activity = Time.now
          @state = Stream::Client::Start.new(self)
          @requests, @responses = [], []
          @pinged = false
          start_session(rid)
        end

        def method_missing(method, *args, &block)
          @stream.send(method, *args, &block)
        end

        def send_response(data, rid)
          doc = Document.new
          body = doc.create_element('body',
            'rid' => rid,
            'sid' => @sid,
            'xmlns' => NAMESPACES[:http_bind]) do |node|
              node.inner_html = data.to_s
            end
          reply(body)
        end

        def expired?
          cleanup_requests
          @requests.empty? && (Time.now - @last_activity > 65)
        end

        def ping
          log.debug("Pinging #{self}. Request queue: #{@requests}")
          @last_activity = Time.now
          write("")
          @pinged = true
        end

        def pinged?
          @pinged
        end

        def request(rid)
          @pinged = false
          @last_activity = Time.now
          if @responses.any?
            send_response(@responses.join(' '), rid)
            @responses.clear
          else
            @requests << HttpRequest.new(rid)
          end
        end

        def write(node)
          if request = @requests.shift
            send_response(node, request.rid)
          else
            @responses << node.to_s
          end
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

        def cleanup_requests
          expired = @requests.select {|request| request.expired? }
          expired.each do |request|
            send_response('', request.rid)
            @requests.delete(request)
          end
        end

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

        def start_session(rid)
          doc = Document.new
          node = doc.create_element('body',
            'accept'     => 'deflate,gzip',
            'ack'        => rid,
            'charsets'   => 'UTF-8',
            'from'       => @domain, 
            'hold'       => '1',
            'inactivity' => '30',
            'maxpause'   => '120',
            'polling'    => '5',
            'requests'   => '2',
            'sid'        => @sid,
            'ver'        => '1.6',
            'wait'       => '60',
            'xmlns'      => 'http://jabber.org/protocol/httpbind')

          node << doc.create_element('features', 'xmlns' => 'jabber:client') do |el|
            el << doc.create_element('mechanisms') do |mechanisms|
              mechanisms.default_namespace = NAMESPACES[:sasl]
              mechanisms << doc.create_element('mechanism', 'EXTERNAL')
              mechanisms << doc.create_element('mechanism', 'PLAIN')
            end
          end
          reply(node)
        end
      end
    end
  end
end

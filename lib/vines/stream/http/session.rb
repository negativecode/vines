# encoding: UTF-8

module Vines
  class Stream
    class Http
      class Session < Client::Session
        include Nokogiri::XML

        attr_accessor :content_type, :hold, :inactivity, :wait

        CONTENT_TYPE = 'text/xml; charset=utf-8'.freeze

        def initialize(stream)
          super
          @state = Http::Start.new(stream)
          @inactivity, @wait, @hold = 20, 60, 1
          @replied = Time.now
          @requests, @responses = [], []
          @content_type = CONTENT_TYPE
        end

        def close
          Sessions.delete(@id)
          router.delete(self)
          delete_from_cluster
          unsubscribe_pubsub
          @requests.each {|req| req.stream.close_connection }
          @requests.clear
          @responses.clear
          @state = Client::Closed.new(nil)
          @unbound = true
          @available = false
          broadcast_unavailable
        end

        def ready?
          @state.class == Http::Ready
        end

        def requests
          @requests.clone
        end

        def expired?
          respond_to_expired_requests
          @requests.empty? && (Time.now - @replied > @inactivity)
        end

        # Resume this session from its most recent state with a new client
        # stream and incoming node.
        def resume(stream, node)
          stream.session.requests.each do |req|
            request(req)
          end
          stream.session = self
          @state.stream = stream
          @state.node(node)
        end

        def request(request)
          if @responses.any?
            request.reply(wrap_body(@responses.join), @content_type)
            @replied = Time.now
            @responses.clear
          else
            while @requests.size >= @hold
              @requests.shift.reply(wrap_body(''), @content_type)
              @replied = Time.now
            end
            @requests << request
          end
        end

        # Send an HTTP 200 OK response wrapping the XMPP node content back
        # to the client.
        #
        # node - The XML::Node to send to the client.
        #
        # Returns nothing.
        def reply(node)
          if request = @requests.shift
            request.reply(node, @content_type)
            @replied = Time.now
          end
        end

        # Write the XMPP node to the client stream after wrapping it in a BOSH
        # body tag. If there's a waiting request, the node is written
        # immediately. If not, it's queued until the next request arrives.
        #
        # data - The XML String or XML::Node to send in the next HTTP response.
        #
        # Returns nothing.
        def write(node)
          if request = @requests.shift
            request.reply(wrap_body(node), @content_type)
            @replied = Time.now
          else
            @responses << node.to_s
          end
        end

        def unbind!(stream)
          @requests.reject! {|req| req.stream == stream }
        end

        private

        def respond_to_expired_requests
          expired = @requests.select {|req| req.age > @wait }
          expired.each do |request|
            request.reply(wrap_body(''), @content_type)
            @requests.delete(request)
            @replied = Time.now
          end
        end

        def wrap_body(data)
          doc = Document.new
          doc.create_element('body') do |node|
            node.add_namespace(nil, NAMESPACES[:http_bind])
            node.inner_html = data.to_s
          end
        end
      end
    end
  end
end

# encoding: UTF-8

module Vines
  class Stream
    class Http < Client
      attr_accessor :session

      def initialize(config)
        super
        @session = Http::Session.new(self)
      end

      def post_init
        super
        router.delete(self)
        @parser = ::Http::Parser.new.tap do |p|
          body = ''
          p.on_body = proc {|data| body << data }
          p.on_message_complete = proc {
            process_request(Request.new(self, @parser, body))
            body = ''
          }
        end
      end

      # If the session ID is valid, switch this stream's session to the new
      # ID and return true. Some clients, like Google Chrome, reuse one stream
      # for multiple sessions.
      def valid_session?(sid)
        if session = Sessions[sid]
          @session = session
        end
        !!session
      end

      %w[max_stanza_size max_resources_per_account bind root].each do |name|
        define_method name do |*args|
          config[:http].send(name, *args)
        end
      end

      def process_request(request)
        if request.path == self.bind
          body = Nokogiri::XML(request.body).root
          if session = Sessions[body['sid']]
            @session = session
          else
            @session = Http::Session.new(self)
          end
          @session.request(request)
          @nodes.push(body)
        else
          request.reply_with_file(self.root)
        end
      end

      # Alias the Stream#write method before overriding it so we can call
      # it later from a Session instance.
      alias :stream_write :write

      # Override Stream#write to queue stanzas rather than immediately writing
      # to the stream. Stanza responses must be paired with a queued request.
      def write(data)
        @session.write(data)
      end

      # Return an array of Node objects inside the body element.
      # TODO This parses the XML again just to strip namespaces. Figure out
      # Nokogiri namespace handling instead.
      def parse_body(body)
        body.namespace = nil
        body.elements.map do |node|
          Nokogiri::XML(node.to_s.sub(' xmlns="jabber:client"', '')).root
        end
      end

      def start(node)
        domain, type, hold, wait, rid = %w[to content hold wait rid].map {|a| (node[a] || '').strip }
        version = node.attribute_with_ns('version', NAMESPACES[:bosh]).value rescue nil

        @session.inactivity = 20
        @session.domain = domain
        @session.content_type = type unless type.empty?
        @session.hold = hold.to_i unless hold.empty?
        @session.wait = wait.to_i unless wait.empty?

        raise StreamErrors::UndefinedCondition.new('rid required') if rid.empty?
        raise StreamErrors::UnsupportedVersion unless version == '1.0'
        raise StreamErrors::ImproperAddressing unless valid_address?(domain)
        raise StreamErrors::HostUnknown unless config.vhost?(domain)
        raise StreamErrors::InvalidNamespace unless node.namespaces['xmlns'] == NAMESPACES[:http_bind]

        Sessions[@session.id] = @session
        router << @session
        send_stream_header
      end

      def terminate
        doc = Nokogiri::XML::Document.new
        node = doc.create_element('body',
          'type'  => 'terminate',
          'xmlns' => NAMESPACES[:http_bind])
        @session.reply(node)
        close_stream
      end

      private

      def send_stream_header
        doc = Nokogiri::XML::Document.new
        node = doc.create_element('body',
          'charsets'     => 'UTF-8',
          'from'         => @session.domain, 
          'hold'         => @session.hold,
          'inactivity'   => @session.inactivity,
          'polling'      => '5',
          'requests'     => '2',
          'sid'          => @session.id,
          'ver'          => '1.6',
          'wait'         => @session.wait,
          'xmpp:version' => '1.0',
          'xmlns'        => NAMESPACES[:http_bind],
          'xmlns:xmpp'   => NAMESPACES[:bosh],
          'xmlns:stream' => NAMESPACES[:stream])

        node << doc.create_element('stream:features') do |el|
          el << doc.create_element('mechanisms') do |mechanisms|
            mechanisms.default_namespace = NAMESPACES[:sasl]
            mechanisms << doc.create_element('mechanism', 'PLAIN')
          end
        end
        @session.reply(node)
      end

      # Override +Stream#send_stream_error+ to wrap the error XML in a BOSH
      # terminate body tag.
      def send_stream_error(e)
        doc = Nokogiri::XML::Document.new
        node = doc.create_element('body',
          'condition'    => 'remote-stream-error',
          'type'         => 'terminate',
          'xmlns'        => NAMESPACES[:http_bind],
          'xmlns:stream' => NAMESPACES[:stream])
        node.inner_html = e.to_xml
        @session.reply(node)
      end

      # Override +Stream#close_stream+ to simply close the connection without
      # writing a closing stream tag.
      def close_stream
        close_connection_after_writing
        @session.close
      end
    end
  end
end
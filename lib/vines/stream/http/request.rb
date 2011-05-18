# encoding: UTF-8

module Vines
  class Stream
    class Http
      class Request
        attr_reader :rid, :stream

        def initialize(stream, rid, content_type)
          @stream, @rid, @content = stream, rid, content_type
          @received = Time.now
        end

        # Return the number of seconds since this request was received.
        def age
          Time.now - @received
        end

        # Send an HTTP 200 OK response wrapping the XMPP node content back
        # to the client.
        def reply(node)
          body = node.to_s
          header = [
            "HTTP/1.1 200 OK",
            "Content-Type: #{@content}",
            "Content-Length: #{body.bytesize}"
          ].join("\r\n")
          @stream.stream_write([header, body].join("\r\n\r\n"))
        end
      end
    end
  end
end
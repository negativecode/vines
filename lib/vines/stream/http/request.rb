# encoding: UTF-8

module Vines
  class Stream
    class Http
      class Request
        BUF_SIZE      = 1024
        MODIFIED      = '%a, %d %b %Y %H:%M:%S GMT'.freeze
        NOT_FOUND     = 'Not Found'.freeze
        NOT_MODIFIED  = 'Not Modified'.freeze
        IF_MODIFIED   = 'If-Modified-Since'.freeze
        TEXT_PLAIN    = 'text/plain'.freeze
        CONTENT_TYPES = {
          'html' => 'text/html; charset="utf-8"',
          'js'   => 'application/javascript; charset="utf-8"',
          'css'  => 'text/css',
          'png'  => 'image/png',
          'jpg'  => 'image/jpeg',
          'jpeg' => 'image/jpeg',
          'gif'  => 'image/gif'
        }.freeze

        attr_reader :stream, :body, :headers, :method, :path, :url, :query

        def initialize(stream, parser, body)
          @stream, @body = stream, body
          @headers  = parser.headers
          @method   = parser.http_method
          @path     = parser.request_path
          @url      = parser.request_url
          @query    = parser.query_string
          @received = Time.now
        end

        # Return the number of seconds since this request was received.
        def age
          Time.now - @received
        end

        # Write the requested file to the client out of the given document root
        # directory. Take care to prevent directory traversal attacks with paths
        # like ../../../etc/passwd. Use the If-Modified-Since request header
        # to implement caching.
        def reply_with_file(dir)
          path = File.expand_path(File.join(dir, @path))
          path = File.join(path, 'index.html') if File.directory?(path)

          if path.start_with?(dir) && File.exist?(path)
            modified?(path) ? send_file(path) : send_status(304, NOT_MODIFIED)
          else
            missing = File.join(dir, '404.html')
            if File.exist?(missing)
              send_file(missing, 404, NOT_FOUND)
            else
              send_status(404, NOT_FOUND)
            end
          end
        end

        # Send an HTTP 200 OK response wrapping the XMPP node content back
        # to the client.
        def reply(node, content_type)
          body = node.to_s
          header = [
            "HTTP/1.1 200 OK",
            "Content-Type: #{content_type}",
            "Content-Length: #{body.bytesize}"
          ].join("\r\n")
          @stream.stream_write([header, body].join("\r\n\r\n"))
        end

        private

        # Return true if the file has been modified since the client last
        # requested it with the If-Modified-Since header.
        def modified?(path)
          @headers[IF_MODIFIED] != mtime(path)
        end

        def mtime(path)
          File.mtime(path).utc.strftime(MODIFIED)
        end

        def send_status(status, message)
          header = [
            "HTTP/1.1 #{status} #{message}",
            "Connection: close"
          ].join("\r\n")
          @stream.stream_write("#{header}\r\n\r\n")
          @stream.close_connection_after_writing
        end

        # Stream the contents of the file to the client in a 200 OK response.
        # Send a Last-Modified response header so clients can send us an
        # If-Modified-Since request header for caching.
        def send_file(path, status=200, message='OK')
          header = [
            "HTTP/1.1 #{status} #{message}",
            "Connection: close",
            "Content-Type: #{content_type(path)}",
            "Content-Length: #{File.size(path)}",
            "Last-Modified: #{mtime(path)}"
          ].join("\r\n")
          @stream.stream_write("#{header}\r\n\r\n")

          File.open(path) do |file|
            while (buf = file.read(BUF_SIZE)) != nil
              @stream.stream_write(buf)
            end
          end
          @stream.close_connection_after_writing
        end

        def content_type(path)
          ext = File.extname(path).sub('.', '')
          CONTENT_TYPES[ext] || TEXT_PLAIN
        end
      end
    end
  end
end
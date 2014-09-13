# encoding: UTF-8

module Vines
  class Stream
    class Http
      class Request
        BUF_SIZE      = 1024
        MODIFIED      = '%a, %d %b %Y %H:%M:%S GMT'.freeze
        MOVED         = 'Moved Permanently'.freeze
        NOT_FOUND     = 'Not Found'.freeze
        NOT_MODIFIED  = 'Not Modified'.freeze
        IF_MODIFIED   = 'If-Modified-Since'.freeze
        TEXT_PLAIN    = 'text/plain'.freeze
        OPTIONS       = 'OPTIONS'.freeze
        CONTENT_TYPES = {
          'html'     => 'text/html; charset="utf-8"',
          'js'       => 'application/javascript; charset="utf-8"',
          'css'      => 'text/css',
          'png'      => 'image/png',
          'jpg'      => 'image/jpeg',
          'jpeg'     => 'image/jpeg',
          'gif'      => 'image/gif',
          'manifest' => 'text/cache-manifest'
        }.freeze

        attr_reader :stream, :body, :headers, :method, :path, :url, :query

        # Create a new request parsed from an HTTP client connection. We'll try
        # to keep this request open until there are stanzas available to send
        # as a response.
        #
        # stream - The Stream::Http client connection that received the request.
        # parser - The Http::Parser that parsed the HTTP request.
        # body   - The String request body.
        def initialize(stream, parser, body)
          uri       = URI(parser.request_url)
          @stream   = stream
          @body     = body
          @headers  = parser.headers
          @method   = parser.http_method
          @url      = parser.request_url
          @path     = uri.path
          @query    = uri.query
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
        #
        # Returns nothing.
        def reply_with_file(dir)
          path = File.expand_path(File.join(dir, @path))

          # Redirect requests missing a slash so relative links work.
          if File.directory?(path) && !@path.end_with?('/')
            send_status(301, MOVED, "Location: #{redirect_uri}")
            return
          end

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
        #
        # Returns nothing.
        def reply(node, content_type)
          body = node.to_s
          header = [
            "HTTP/1.1 200 OK",
            "Access-Control-Allow-Origin: *",
            "Content-Type: #{content_type}",
            "Content-Length: #{body.bytesize}",
            vroute_cookie
          ].compact.join("\r\n")
          @stream.stream_write([header, body].join("\r\n\r\n"))
        end

        # Return true if the request method is OPTIONS, signaling a
        # CORS preflight check.
        def options?
          @method == OPTIONS
        end

        # Send a 200 OK response, allowing any origin domain to connect to the
        # server, in response to CORS preflight OPTIONS requests. This allows
        # any web application using strophe.js to connect to our BOSH port.
        #
        # Returns nothing.
        def reply_to_options
          allow = @headers['Access-Control-Request-Headers']
          headers = [
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Methods: POST, GET, OPTIONS",
            "Access-Control-Allow-Headers: #{allow}",
            "Access-Control-Max-Age: #{60 * 60 * 24 * 30}"
          ]
          send_status(200, 'OK', headers)
        end

        private

        # Attempt to rebuild the full request URI from the Host header. If it
        # wasn't sent by the client, just return the relative path that
        # was requested. The Location response header must contain the fully
        # qualified URI, but most browsers will accept relative paths as well.
        #
        # Returns the String URL.
        def redirect_uri
          host = headers['Host']
          uri = "#{path}/"
          uri = "#{uri}?#{query}" unless (query || '').empty?
          uri = "http://#{host}#{uri}" if host
          uri
        end

        # Return true if the file has been modified since the client last
        # requested it with the If-Modified-Since header.
        def modified?(path)
          @headers[IF_MODIFIED] != mtime(path)
        end

        def mtime(path)
          File.mtime(path).utc.strftime(MODIFIED)
        end

        def send_status(status, message, *headers)
          header = [
            "HTTP/1.1 #{status} #{message}",
            "Content-Length: 0",
            *headers
          ].join("\r\n")
          @stream.stream_write("#{header}\r\n\r\n")
        end

        # Stream the contents of the file to the client in a 200 OK response.
        # Send a Last-Modified response header so clients can send us an
        # If-Modified-Since request header for caching.
        #
        # Returns nothing.
        def send_file(path, status=200, message='OK')
          header = [
            "HTTP/1.1 #{status} #{message}",
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
        end

        def content_type(path)
          ext = File.extname(path).sub('.', '')
          CONTENT_TYPES[ext] || TEXT_PLAIN
        end

        # Provide a vroute cookie in each response that uniquely identifies this
        # HTTP server. Reverse proxy servers (nginx/apache) can use this cookie
        # to implement sticky sessions. Return nil if vroute was not set in
        # config.rb and no cookie should be sent.
        #
        # Returns a String cookie value or nil if disabled.
        def vroute_cookie
          route = @stream.config[:http].vroute
          route ? "Set-Cookie: vroute=#{route}; path=/; HttpOnly" : nil
        end
      end
    end
  end
end

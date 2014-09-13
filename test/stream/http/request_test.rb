# encoding: UTF-8

require 'test_helper'

describe Vines::Stream::Http::Request do
  PASSWORD = File.expand_path('../passwords').freeze
  INDEX    = File.expand_path('index.html').freeze

  before do
    File.open(PASSWORD, 'w') {|f| f.puts '/etc/passwd contents' }
    File.open(INDEX, 'w') {|f| f.puts 'index.html contents' }

    @stream = MiniTest::Mock.new
    @parser = MiniTest::Mock.new
    @parser.expect(:headers, {'Content-Type' => 'text/html', 'Host' => 'wonderland.lit'})
    @parser.expect(:http_method, 'GET')
    @parser.expect(:request_path, '/blogs/12')
    @parser.expect(:request_url, '/blogs/12?ok=true')
    @parser.expect(:query_string, 'ok=true')
  end

  after do
    File.delete(PASSWORD)
    File.delete(INDEX)
  end

  describe 'initialize' do
    it 'copies request info from parser' do
      request = Vines::Stream::Http::Request.new(@stream, @parser, '<html></html>')
      assert_equal request.headers, {'Content-Type' => 'text/html', 'Host' => 'wonderland.lit'}
      assert_equal request.method, 'GET'
      assert_equal request.path, '/blogs/12'
      assert_equal request.url, '/blogs/12?ok=true'
      assert_equal request.query, 'ok=true'
      assert_equal request.body, '<html></html>'
      assert @stream.verify
      assert @parser.verify
    end
  end

  describe 'reply_with_file' do
    it 'returns 404 file not found' do
      request = Vines::Stream::Http::Request.new(@stream, @parser, '<html></html>')
      headers = [
        "HTTP/1.1 404 Not Found",
        "Content-Length: 0"
      ].join("\r\n")

      @stream.expect(:stream_write, nil, ["#{headers}\r\n\r\n"])

      request.reply_with_file(Dir.pwd)
      assert @stream.verify
      assert @parser.verify
    end

    it 'prevents directory traversal with 404 response' do
      parser = MiniTest::Mock.new
      parser.expect(:headers, {'Content-Type' => 'text/html', 'Host' => 'wonderland.lit'})
      parser.expect(:http_method, 'GET')
      parser.expect(:request_path, '/../passwords')
      parser.expect(:request_url, '/../passwords')
      parser.expect(:query_string, '')

      request = Vines::Stream::Http::Request.new(@stream, parser, '<html></html>')

      headers = [
        "HTTP/1.1 404 Not Found",
        "Content-Length: 0"
      ].join("\r\n")

      @stream.expect(:stream_write, nil, ["#{headers}\r\n\r\n"])

      request.reply_with_file(Dir.pwd)
      assert @stream.verify
      assert parser.verify
    end

    it 'serves index.html for directory request' do
      parser = MiniTest::Mock.new
      parser.expect(:headers, {'Content-Type' => 'text/html', 'Host' => 'wonderland.lit'})
      parser.expect(:http_method, 'GET')
      parser.expect(:request_path, '/')
      parser.expect(:request_url, '/?ok=true')
      parser.expect(:query_string, 'ok=true')

      request = Vines::Stream::Http::Request.new(@stream, parser, '<html></html>')

      mtime = File.mtime(INDEX).utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
      headers = [
        "HTTP/1.1 200 OK",
        'Content-Type: text/html; charset="utf-8"',
        "Content-Length: 20",
        "Last-Modified: #{mtime}"
      ].join("\r\n")

      @stream.expect(:stream_write, nil, ["#{headers}\r\n\r\n"])
      @stream.expect(:stream_write, nil, ["index.html contents\n"])

      request.reply_with_file(Dir.pwd)
      assert @stream.verify
      assert parser.verify
    end

    it 'redirects for missing trailing slash' do
      parser = MiniTest::Mock.new
      parser.expect(:headers, {'Content-Type' => 'text/html', 'Host' => 'wonderland.lit'})
      parser.expect(:http_method, 'GET')
      parser.expect(:request_path, '/http')
      parser.expect(:request_url, '/http?ok=true')
      parser.expect(:query_string, 'ok=true')

      request = Vines::Stream::Http::Request.new(@stream, parser, '<html></html>')

      headers = [
        "HTTP/1.1 301 Moved Permanently",
        "Content-Length: 0",
        "Location: http://wonderland.lit/http/?ok=true"
      ].join("\r\n")

      @stream.expect(:stream_write, nil, ["#{headers}\r\n\r\n"])
      # so the /http url above will work
      request.reply_with_file(File.expand_path('../../', __FILE__))
      assert @stream.verify
      assert parser.verify
    end
  end

  describe 'reply_to_options' do
    it 'returns cors headers' do
      parser = MiniTest::Mock.new
      parser.expect(:headers, {
        'Content-Type' => 'text/xml',
        'Host' => 'wonderland.lit',
        'Origin' => 'remote.wonderland.lit',
        'Access-Control-Request-Headers' => 'Content-Type, Origin'})
      parser.expect(:http_method, 'OPTIONS')
      parser.expect(:request_path, '/xmpp')
      parser.expect(:request_url, '/xmpp')
      parser.expect(:query_string, '')

      request = Vines::Stream::Http::Request.new(@stream, parser, '')

      headers = [
        "HTTP/1.1 200 OK",
        "Content-Length: 0",
        "Access-Control-Allow-Origin: *",
        "Access-Control-Allow-Methods: POST, GET, OPTIONS",
        "Access-Control-Allow-Headers: Content-Type, Origin",
        "Access-Control-Max-Age: 2592000"
      ].join("\r\n")

      @stream.expect(:stream_write, nil, ["#{headers}\r\n\r\n"])
      request.reply_to_options
      assert @stream.verify
      assert parser.verify
    end
  end

  describe 'reply' do
    it 'returns set-cookie header when vroute is defined' do
      reply_with_cookie('v1')
    end

    it 'does not return set-cookie header when vroute is undefined' do
      reply_with_cookie('')
    end
  end

  private

  def reply_with_cookie(cookie)
    config = Vines::Config.new do
      host 'wonderland.lit' do
        storage(:fs) { dir Dir.tmpdir }
      end
      http '0.0.0.0', 5280 do
        vroute cookie
      end
    end

    parser = MiniTest::Mock.new
    parser.expect(:headers, {
      'Content-Type' => 'text/xml',
      'Host' => 'wonderland.lit',
      'Origin' => 'remote.wonderland.lit'})
    parser.expect(:http_method, 'POST')
    parser.expect(:request_path, '/xmpp')
    parser.expect(:request_url, '/xmpp')
    parser.expect(:query_string, '')

    request = Vines::Stream::Http::Request.new(@stream, parser, '')
    message = '<message>hello</message>'

    headers = [
      "HTTP/1.1 200 OK",
      "Access-Control-Allow-Origin: *",
      "Content-Type: application/xml",
      "Content-Length: 24",
    ]
    headers << "Set-Cookie: vroute=#{cookie}; path=/; HttpOnly" unless cookie.empty?
    headers = headers.join("\r\n")

    @stream.expect(:stream_write, nil, ["#{headers}\r\n\r\n#{message}"])
    @stream.expect(:config, config)
    request.reply(message, 'application/xml')
    assert @stream.verify
    assert parser.verify
  end
end

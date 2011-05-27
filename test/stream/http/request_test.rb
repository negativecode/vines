# encoding: UTF-8

require 'vines'
require 'minitest/autorun'

class RequestTest < MiniTest::Unit::TestCase
  PASSWORD = File.expand_path('../passwords')
  INDEX    = File.expand_path('index.html')

  def setup
    File.open(PASSWORD, 'w') {|f| f.puts '/etc/passwd contents' }
    File.open(INDEX, 'w') {|f| f.puts 'index.html contents' }

    @stream = MiniTest::Mock.new
    @parser = MiniTest::Mock.new
    @parser.expect(:headers, {'Content-Type' => 'text/html'})
    @parser.expect(:http_method, 'GET')
    @parser.expect(:request_path, '/blogs/12')
    @parser.expect(:request_url, '/blogs/12?ok=true')
    @parser.expect(:query_string, 'ok=true')
  end

  def teardown
    File.delete(PASSWORD)
    File.delete(INDEX)
  end

  def test_copies_request_info_from_parser
    request = Vines::Stream::Http::Request.new(@stream, @parser, '<html></html>')
    assert_equal request.headers, {'Content-Type' => 'text/html'}
    assert_equal request.method, 'GET'
    assert_equal request.path, '/blogs/12'
    assert_equal request.url, '/blogs/12?ok=true'
    assert_equal request.query, 'ok=true'
    assert_equal request.body, '<html></html>'
    assert @stream.verify
    assert @parser.verify
  end

  def test_reply_with_file_404
    request = Vines::Stream::Http::Request.new(@stream, @parser, '<html></html>')

    expected = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n"
    @stream.expect(:stream_write, nil, [expected])
    @stream.expect(:close_connection_after_writing, nil)

    request.reply_with_file(Dir.pwd)
    assert @stream.verify
    assert @parser.verify
  end

  def test_reply_with_file_directory_traversal
    @parser.expect(:request_path, '../passwords')
    request = Vines::Stream::Http::Request.new(@stream, @parser, '<html></html>')

    expected = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n"
    @stream.expect(:stream_write, nil, [expected])
    @stream.expect(:close_connection_after_writing, nil)

    request.reply_with_file(Dir.pwd)
    assert @stream.verify
    assert @parser.verify
  end

  def test_reply_with_file_for_directory_serves_index_html
    @parser.expect(:request_path, '/')
    request = Vines::Stream::Http::Request.new(@stream, @parser, '<html></html>')

    mtime = File.mtime(INDEX).utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
    headers = [
      "HTTP/1.1 200 OK",
      "Connection: close",
      'Content-Type: text/html; charset="utf-8"',
      "Content-Length: 20",
      "Last-Modified: #{mtime}"
    ].join("\r\n")

    @stream.expect(:stream_write, nil, ["#{headers}\r\n\r\n"])
    @stream.expect(:stream_write, nil, ["index.html contents\n"])
    @stream.expect(:close_connection_after_writing, nil)

    request.reply_with_file(Dir.pwd)
    assert @stream.verify
    assert @parser.verify
  end
end

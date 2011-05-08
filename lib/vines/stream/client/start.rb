# encoding: UTF-8

module Vines
  class Stream
    class Client
      class Start < State
        def initialize(stream, success=TLS)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          stream.start(node)
          doc = Document.new
          features = doc.create_element('stream:features') do |el|
            el << doc.create_element('starttls') do |tls|
              tls.default_namespace = NAMESPACES[:tls]
              tls << doc.create_element('required')
            end
          end
          stream.write(features)
          advance
        end
      end
    end
  end
end

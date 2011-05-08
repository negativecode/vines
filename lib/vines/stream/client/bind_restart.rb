# encoding: UTF-8

module Vines
  class Stream
    class Client
      class BindRestart < State
        def initialize(stream, success=Bind)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          stream.start(node)
          doc = Document.new
          features = doc.create_element('stream:features') do |el|
            el << doc.create_element('bind', 'xmlns' => NAMESPACES[:bind])
            el << doc.create_element('session', 'xmlns' => NAMESPACES[:session])
          end
          stream.write(features)
          advance
        end  
      end
    end
  end
end

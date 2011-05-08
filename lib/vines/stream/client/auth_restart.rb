# encoding: UTF-8

module Vines
  class Stream
    class Client
      class AuthRestart < State
        def initialize(stream, success=Auth)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless stream?(node)
          stream.start(node)
          doc = Document.new
          features = doc.create_element('stream:features') do |el|
            el << doc.create_element('mechanisms') do |parent|
              parent.default_namespace = NAMESPACES[:sasl]
              mechanisms.each {|name| parent << doc.create_element('mechanism', name) }
            end
          end
          stream.write(features)
          advance
        end

        private

        def mechanisms
          ['EXTERNAL', 'PLAIN']
        end
      end
    end
  end
end

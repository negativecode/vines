# encoding: UTF-8

module Vines
  class Stream
    class Http
      class BindRestart < State
        def initialize(stream, success=Bind)
          super
        end

        def node(node)
          raise StreamErrors::NotAuthorized unless body?(node) && restart?(node)

          doc = Document.new
          body = doc.create_element('body') do |el|
            el.add_namespace(nil, NAMESPACES[:http_bind])
            el.add_namespace('stream', NAMESPACES[:stream])
            el << doc.create_element('stream:features') do |features|
              features << doc.create_element('bind', 'xmlns' => NAMESPACES[:bind])
            end
          end
          stream.reply(body)
          advance
        end

        private

        def restart?(node)
          restart = node.attribute_with_ns('restart', NAMESPACES[:bosh]).value rescue nil
          domain = node['to'] == stream.domain
          domain && restart == 'true' && node['rid'] && stream.valid_session?(node['sid'])
        end
      end
    end
  end
end

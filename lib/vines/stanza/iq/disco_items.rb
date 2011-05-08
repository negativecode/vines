# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class DiscoItems < Query
        NS = NAMESPACES[:disco_items]

        register "/iq[@id and @type='get']/ns:query", 'ns' => NS

        def process
          return if route_iq
          result = to_result.tap do |el|
            el << el.document.create_element('query') do |query|
              query.default_namespace = NS
            end
          end
          stream.write(result)
        end
      end
    end
  end
end

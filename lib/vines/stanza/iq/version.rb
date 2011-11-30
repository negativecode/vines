# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Version < Query
        NS = NAMESPACES[:version]

        register "/iq[@id and @type='get']/ns:query", 'ns' => NS

        def process
          return if route_iq || to_pubsub_domain?
          result = to_result.tap do |node|
            node << node.document.create_element('query') do |query|
              query.default_namespace = NS
              query << node.document.create_element('name', 'Vines')
              query << node.document.create_element('version', VERSION)
            end
          end
          stream.write(result)
        end
      end
    end
  end
end

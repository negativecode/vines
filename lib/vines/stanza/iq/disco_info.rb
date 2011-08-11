# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class DiscoInfo < Query
        NS = NAMESPACES[:disco_info]

        register "/iq[@id and @type='get']/ns:query", 'ns' => NS

        def process
          return if route_iq
          result = to_result.tap do |el|
            el << el.document.create_element('query') do |query|
              query.default_namespace = NS
              query << el.document.create_element('identity', 'category' => 'server', 'type' => 'im')
              query << el.document.create_element('feature', 'var' => NAMESPACES[:disco_info])
              query << el.document.create_element('feature', 'var' => NAMESPACES[:disco_items])
              query << el.document.create_element('feature', 'var' => NAMESPACES[:ping])
              query << el.document.create_element('feature', 'var' => NAMESPACES[:vcard])
              query << el.document.create_element('feature', 'var' => NAMESPACES[:version])
              if stream.config.private_storage?(stream.domain)
                query << el.document.create_element('feature', 'var' => NAMESPACES[:storage])
              end
            end
          end
          stream.write(result)
        end
      end
    end
  end
end

# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class DiscoInfo < Query
        NS = NAMESPACES[:disco_info]

        register "/iq[@id and @type='get']/ns:query", 'ns' => NS

        def process
          return if route_iq || !allowed?
          result = to_result.tap do |el|
            el << el.document.create_element('query') do |query|
              query.default_namespace = NS
              if to_pubsub_domain?
                identity(query, 'pubsub', 'service')
                features(query, :disco_info, :ping, :pubsub)
              else
                identity(query, 'server', 'im')
                features = [:disco_info, :disco_items, :ping, :vcard, :version]
                features << :storage if stream.config.private_storage?(validate_to || stream.domain)
                features(query, features)
              end
            end
          end
          stream.write(result)
        end

        private

        def identity(query, category, type)
          query << query.document.create_element('identity', 'category' => category, 'type' => type)
        end

        def features(query, *features)
          features.flatten.each do |feature|
            query << query.document.create_element('feature', 'var' => NAMESPACES[feature])
          end
        end
      end
    end
  end
end

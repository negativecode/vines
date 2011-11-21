# encoding: UTF-8

module Vines
  class Stream
    class Client
      class Bind < State
        NS = NAMESPACES[:bind]
        MAX_ATTEMPTS = 5

        def initialize(stream, success=Ready)
          super
          @attempts = 0
        end

        def node(node)
          @attempts += 1
          raise StreamErrors::NotAuthorized unless bind?(node)
          raise StreamErrors::PolicyViolation.new('max bind attempts reached') if @attempts > MAX_ATTEMPTS
          raise StanzaErrors::ResourceConstraint.new(node, 'wait') if resource_limit_reached?

          stream.bind!(resource(node))
          doc = Document.new
          result = doc.create_element('iq', 'id' => node['id'], 'type' => 'result') do |el|
            el << doc.create_element('bind') do |bind|
              bind.default_namespace = NS
              bind << doc.create_element('jid', stream.user.jid.to_s)
            end
          end
          stream.write(result)
          send_empty_features
          advance
        end

        private

        # Write the final <stream:features/> element to the stream, indicating
        # stream negotiation is complete and the client is cleared to send
        # stanzas.
        def send_empty_features
          stream.write('<stream:features/>')
        end

        def bind?(node)
          node.name == 'iq' && node['type'] == 'set' && node.xpath('ns:bind', 'ns' => NS).any?
        end

        def resource(node)
          el = node.xpath('ns:bind/ns:resource', 'ns' => NS).first
          resource = el ? el.text.strip : ''
          resource.empty? || resource_used?(resource) ? Kit.uuid : resource
        end

        def resource_limit_reached?
          used = stream.connected_resources(stream.user.jid.bare).size
          used >= stream.max_resources_per_account
        end

        def resource_used?(resource)
          stream.available_resources(stream.user.jid).any? do |c|
            c.user.jid.resource == resource
          end
        end
      end
    end
  end
end

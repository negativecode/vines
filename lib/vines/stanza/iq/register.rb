# encoding: UTF-8

module Vines
  class Stanza
    class Iq
      class Register < Query
        NS = NAMESPACES[:register]

        register "/iq[@id and @type='set']/ns:query", 'ns' => NS

        def process
          if is_stream_owner
            current_user = storage(stream.domain).find_user(stream.user.jid)
            password = @node.xpath("//iq/jir:query//jir:password", {"jir"=>"jabber:iq:register"}).text
            unless password.nil?
              current_user.password = BCrypt::Password.create(password.to_s)
              storage.save_user(current_user)
              stream.write(to_result)
            else
             raise StanzaErrors::NotAcceptable.new(self, 'cancel')
            end
          else

          end
        end

        private

        def is_stream_owner
          stream.user.jid.bare == jid_from_username.bare
        end

        def jid_from_username
          username = @node.xpath("//iq/jir:query//jir:username", {"jir"=>"jabber:iq:register"}).text
          dom = @node.attributes["to"].text
          JID.new(username, dom)
        end

      end
    end
  end
end

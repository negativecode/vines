# encoding: UTF-8

module Vines
  class Storage
    # A storage implementation that does not persist data to any form of storage.
    # When looking up the storage object for a domain, it's easier to treat a
    # missing domain with a Null storage than checking for nil.
    #
    # For example, presence subscription stanzas sent to a pubsub subdomain
    # have no storage. Rather than checking for nil storage or pubsub addresses,
    # it's easier to treat stanzas to pubsub domains as Null storage that never
    # finds or saves users and their rosters.
    class Null < Storage
      def find_user(jid)
        nil
      end

      def save_user(user)
        # do nothing
      end

      def find_vcard(jid)
        nil
      end

      def save_vcard(jid, card)
        # do nothing
      end

      def find_fragment(jid, node)
        nil
      end

      def save_fragment(jid, node)
        # do nothing
      end
    end
  end
end

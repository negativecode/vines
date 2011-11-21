# encoding: UTF-8

module Vines
  class Storage
    class Redis < Storage
      register :redis

      %w[host port database password].each do |name|
        define_method(name) do |*args|
          if args.first
            @config[name.to_sym] = args.first
          else
            @config[name.to_sym]
          end
        end
      end

      def initialize(&block)
        @config = {}
        instance_eval(&block)
      end

      def find_user(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        response = query(:get, "user:#{jid}")
        return unless response
        doc = JSON.parse(response) rescue nil
        return unless doc
        User.new(jid: jid).tap do |user|
          user.name, user.password = doc.values_at('name', 'password')
          user.roster = find_roster(jid)
        end
      end

      def save_user(user)
        doc = {name: user.name, password: user.password}
        contacts = user.roster.map {|c| [c.jid.to_s, c.to_h.to_json] }.flatten
        roster = "roster:#{user.jid.bare}"
        query(:multi)
        query(:set, "user:#{user.jid.bare}", doc.to_json)
        query(:del, roster)
        query(:hmset, roster, *contacts) unless contacts.empty?
        query(:exec)
      end

      def find_vcard(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        response = query(:get, "vcard:#{jid}")
        return unless response
        doc = JSON.parse(response) rescue nil
        Nokogiri::XML(doc['card']).root rescue nil
      end

      def save_vcard(jid, card)
        jid = JID.new(jid).bare.to_s
        doc = {card: card.to_xml}
        query(:set, "vcard:#{jid}", doc.to_json)
      end

      def find_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        response = query(:hget, "fragments:#{jid}", fragment_id(node))
        return unless response
        doc = JSON.parse(response) rescue nil
        Nokogiri::XML(doc['xml']).root rescue nil
      end

      def save_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        doc = {xml: node.to_xml}
        query(:hset, "fragments:#{jid}", fragment_id(node), doc.to_json)
      end

      private

      def fragment_id(node)
        Digest::SHA1.hexdigest("#{node.name}:#{node.namespace.href}")
      end

      # Retrieve the hash stored at roster:jid and return an array of
      # +Vines::Contact+ objects.
      def find_roster(jid)
        jid = JID.new(jid).bare
        roster = query(:hgetall, "roster:#{jid}")
        Hash[*roster].map do |jid, json|
          contact = JSON.parse(json) rescue nil
          Contact.new(
            jid: jid,
            name: contact['name'],
            subscription: contact['subscription'],
            ask: contact['ask'],
            groups: contact['groups'] || []) if contact
        end.compact
      end

      def query(name, *args)
        req = redis.send(name, *args)
        req.callback {|response| yield response }
        req.errback { yield }
      end
      fiber :query

      # Cache and return a redis connection object. The em-hiredis gem reconnects
      # in unbind so only create one connection.
      def redis
        @redis ||= connect
      end

      # Return a new redis connection using the configuration attributes from the
      # conf/config.rb file.
      def connect
        args = @config.values_at(:host, :port, :password, :database)
        conn = EM::Hiredis::Client.new(*args)
        conn.connect
        conn
      end
    end
  end
end

# encoding: UTF-8

module Vines
  class Storage
    class MongoDB < Storage
      register :mongodb

      %w[database tls username password pool].each do |name|
        define_method(name) do |*args|
          if args.first
            @config[name.to_sym] = args.first
          else
            @config[name.to_sym]
          end
        end
      end

      def initialize(&block)
        @config, @hosts = {}, []
        instance_eval(&block)
        raise "Must provide database" unless @config[:database]
        raise "Must provide at least one host connection" if @hosts.empty?
      end

      def host(name, port)
        pair = [name, port]
        raise "duplicate hosts not allowed: #{name}:#{port}" if @hosts.include?(pair)
        @hosts << pair
      end

      def find_user(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        doc = get(:users, jid)
        return unless doc
        User.new(jid: jid).tap do |user|
          user.name, user.password = doc.values_at('name', 'password')
          (doc['roster'] || {}).each_pair do |jid, props|
            user.roster << Contact.new(
              jid: jid,
              name: props['name'],
              subscription: props['subscription'],
              ask: props['ask'],
              groups: props['groups'] || [])
          end
        end
      end

      def save_user(user)
        id = user.jid.bare.to_s
        doc = get(:users, id) || {'_id' => id}
        doc['name'] = user.name
        doc['password'] = user.password
        doc['roster'] = {}
        user.roster.each do |contact|
          doc['roster'][contact.jid.bare.to_s] = contact.to_h
        end
        save_doc(:users, doc)
      end

      def find_vcard(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        doc = get(:vcards, jid)
        return unless doc
        Nokogiri::XML(doc['card']).root rescue nil
      end

      def save_vcard(jid, card)
        jid = JID.new(jid).bare.to_s
        doc = get(:vcards, jid) || {'_id' => jid}
        doc['card'] = card.to_xml
        save_doc(:vcards, doc)
      end

      def find_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        doc = get(:fragments, fragment_id(jid, node))
        return unless doc
        Nokogiri::XML(doc['xml']).root rescue nil
      end

      def save_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        id = fragment_id(jid, node)
        doc = get(:fragments, id) || {'_id' => id}
        doc['xml'] = node.to_xml
        save_doc(:fragments, doc)
      end

      private

      def fragment_id(jid, node)
        id = Digest::SHA1.hexdigest("#{node.name}:#{node.namespace.href}")
        "#{jid}:#{id}"
      end

      def get(collection, id)
        db.collection(collection).find_one({_id: id})
      end
      defer :get

      def save_doc(collection, doc)
        db.collection(collection).save(doc, safe: true)
      end
      defer :save_doc

      def db
        @db ||= connect
      end

      def connect
        opts = {
          pool_timeout: 5,
          pool_size: @config[:pool] || 5,
          ssl: @config[:tls]
        }
        conn = if @hosts.size == 1
          Mongo::Connection.new(@hosts.first[0], @hosts.first[1], opts)
        else
          Mongo::ReplSetConnection.new(*@hosts, opts)
        end
        conn.db(@config[:database]).tap do |db|
          user = @config[:username] || ''
          pass = @config[:password] || ''
          db.authenticate(user, pass) unless user.empty? || pass.empty?
        end
      end
    end
  end
end

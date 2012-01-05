# encoding: UTF-8

require 'em-http'

module Vines
  class Storage
    class CouchDB < Storage
      register :couchdb

      %w[host port database tls username password].each do |name|
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
        [:host, :port, :database].each {|key| raise "Must provide #{key}" unless @config[key] }
        @url = url(@config)
      end

      def find_user(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        doc = get("user:#{jid}")
        return unless doc && doc['type'] == 'User'
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
        id = "user:#{user.jid.bare}"
        doc = get(id) || {'_id' => id}
        doc['type'] = 'User'
        doc['name'] = user.name
        doc['password'] = user.password
        doc['roster'] = {}
        user.roster.each do |contact|
          doc['roster'][contact.jid.bare.to_s] = contact.to_h
        end
        save_doc(doc)
      end

      def find_vcard(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        doc = get("vcard:#{jid}")
        return unless doc && doc['type'] == 'Vcard'
        Nokogiri::XML(doc['card']).root rescue nil
      end

      def save_vcard(jid, card)
        jid = JID.new(jid).bare.to_s
        id = "vcard:#{jid}"
        doc = get(id) || {'_id' => id}
        doc['type'] = 'Vcard'
        doc['card'] = card.to_xml
        save_doc(doc)
      end

      def find_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        doc = get(fragment_id(jid, node))
        return unless doc && doc['type'] == 'Fragment'
        Nokogiri::XML(doc['xml']).root rescue nil
      end

      def save_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        id = fragment_id(jid, node)
        doc = get(id) || {'_id' => id}
        doc['type'] = 'Fragment'
        doc['xml'] = node.to_xml
        save_doc(doc)
      end

      private

      def fragment_id(jid, node)
        id = Digest::SHA1.hexdigest("#{node.name}:#{node.namespace.href}")
        "fragment:#{jid}:#{id}"
      end

      def url(config)
        scheme = config[:tls] ? 'https' : 'http'
        user, password = config.values_at(:username, :password)
        credentials = empty?(user, password) ? '' : "%s:%s@" % [user, password]
        "%s://%s%s:%s/%s" % [scheme, credentials, *config.values_at(:host, :port, :database)]
      end

      def get(jid)
        http = EM::HttpRequest.new("#{@url}/#{escape(jid)}").get
        http.errback { yield }
        http.callback do
          doc = if http.response_header.status == 200
            JSON.parse(http.response) rescue nil
          end
          yield doc
        end
      end
      fiber :get

      def save_doc(doc)
        head = {'Content-Type' => 'application/json'}
        http = EM::HttpRequest.new(@url).post(head: head, body: doc.to_json)
        http.callback { yield }
        http.errback  { yield }
      end
      fiber :save_doc

      def escape(jid)
        URI.escape(jid, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end
    end
  end
end

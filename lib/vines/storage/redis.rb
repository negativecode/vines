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
        @config[:db] = @config.delete(:database) if @config.key?(:database)
      end

      def find_user(jid)
        jid = JID.new(jid || '').bare.to_s
        if jid.empty? then yield; return end
        find_roster(jid) do |contacts|
          redis.get("user:#{jid}") do |response|
            user = if response
              doc = JSON.parse(response) rescue nil
              User.new(:jid => jid).tap do |user|
                user.name, user.password = doc.values_at('name', 'password')
                user.roster = contacts
              end if doc
            end
            yield user
          end
        end
      end
      fiber :find_user

      def save_user(user)
        doc = {:name => user.name, :password => user.password}
        contacts = user.roster.map {|c| [c.jid.to_s, c.to_h.to_json] }.flatten
        roster = "roster:#{user.jid.bare}"

        redis.set("user:#{user.jid.bare}", doc.to_json) do
          redis.del(roster) do
            contacts.empty? ? yield : redis.hmset(roster, *contacts) { yield }
          end
        end
      end
      fiber :save_user

      def find_vcard(jid)
        jid = JID.new(jid || '').bare.to_s
        if jid.empty? then yield; return end
        redis.get("vcard:#{jid}") do |response|
          card = if response
            doc = JSON.parse(response) rescue nil
            Nokogiri::XML(doc['card']).root rescue nil
          end
          yield card
        end
      end
      fiber :find_vcard

      def save_vcard(jid, card)
        jid = JID.new(jid).bare.to_s
        doc = {:card => card.to_xml}
        redis.set("vcard:#{jid}", doc.to_json) do
          yield
        end
      end
      fiber :save_vcard

      private

      # Retrieve the hash stored at roster:jid and yield an array of
      # +Vines::Contact+ objects to the provided block.
      #
      # find_roster('alice@wonderland.lit') do |contacts|
      #   puts contacts.size
      # end
      def find_roster(jid)
        jid = JID.new(jid).bare
        redis.hgetall("roster:#{jid}") do |roster|
          contacts = roster.map do |jid, json|
            contact = JSON.parse(json) rescue nil
            Contact.new(
              :jid => jid,
              :name => contact['name'],
              :subscription => contact['subscription'],
              :ask => contact['ask'],
              :groups => contact['groups'] || []) if contact
          end.compact
          yield contacts
        end
      end

      # Cache and return a redis connection object. The em-redis gem reconnects
      # in unbind so only create one connection.
      def redis
        @redis ||= EM::Protocols::Redis.connect(@config)
      end
    end
  end
end

# encoding: UTF-8

require 'riak'

module Vines
  class Storage
    class Riak < Storage
      register :riak

      %w[nodes].each do |name|
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
        [:nodes].each {|key| raise "Must provide #{key}" unless @config[key] }
      end

      def find_user(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        response = riak.bucket('user')[jid] rescue nil
        return unless response
        doc = response.data rescue nil
        return unless doc
        User.new(jid: jid).tap do |user|
          user.name, user.password = doc.values_at('name', 'password')
          user.roster = find_roster(jid)
        end
      end

      def save_user(user)
        doc = {name: user.name, password: user.password}
        contacts_hash = {}
        user.roster.each do |contact|
          contacts_hash[contact.jid.to_s] = contact.to_h
        end
 
        user_to_save = riak.bucket('user').new(user.jid.bare.to_s)
        user_to_save.content_type = 'application/json'
        user_to_save.data = doc
        user_to_save.store

        unless contacts_hash.empty?
          roster_to_save = riak.bucket('roster').new(user.jid.bare.to_s)
          roster_to_save.content_type = 'application/json'
          roster_to_save.data = contacts_hash
          roster_to_save.store
        end
      end

      def find_vcard(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        response = riak.bucket('vcard')[jid] rescue nil
        return unless response
        doc = response.data
        Nokogiri::XML(doc['card']).root rescue nil
      end

      def save_vcard(jid, card)
        jid = JID.new(jid).bare.to_s
        doc = {card: card.to_xml}
        vcard_to_save = riak.bucket('vcard').new(jid)
        vcard_to_save.content_type = 'application/json'
        vcard_to_save.data = doc
        vcard_to_save.store
      end

      def find_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        response = riak.bucket('fragment')["#{jid}:#{fragment_id(node)}"] rescue nil
        return unless response
        doc = response.data
        Nokogiri::XML(doc['xml']).root rescue nil
      end

      def save_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        doc = {xml: node.to_xml}
        fragment_to_save = riak.bucket('fragment').new("#{jid}:#{fragment_id(node)}")
        fragment_to_save.content_type = 'application/json'
        fragment_to_save.data = doc
        fragment_to_save.store
      end

      private

      def fragment_id(node)
        Digest::SHA1.hexdigest("#{node.name}:#{node.namespace.href}")
      end

      # Retrieve the hash stored at roster:jid and return an array of
      # +Vines::Contact+ objects.
      def find_roster(jid)
        jid = JID.new(jid).bare
        roster = riak.bucket('roster')[jid.to_s] rescue nil
        return unless roster
        contacts = roster.data.map do |jid, contact|
          Contact.new(
            jid: jid,
            name: contact['name'],
            subscription: contact['subscription'],
            ask: contact['ask'],
            groups: contact['groups'] || []) if contact
        end.compact
      end

      # Cache and return a Riak connection object.
      def riak
        @riak ||= connect
      end

      # Return a new redis connection using the configuration attributes from the
      # conf/config.rb file.
      def connect
        ::Riak::Client.new(:nodes => @config[:nodes])
      end
    end
  end
end

# encoding: UTF-8

module Vines
  class Storage
    class Sql < Storage
      register :sql

      class Contact < ActiveRecord::Base
        belongs_to :user
      end
      class Group < ActiveRecord::Base; end
      class User < ActiveRecord::Base
        has_many :contacts
      end

      %w[adapter host port database username password pool].each do |name|
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
        required = [:adapter, :database]
        required << [:host, :port] unless @config[:adapter] == 'sqlite3'
        required.flatten.each {|key| raise "Must provide #{key}" unless @config[key] }
        [:username, :password].each {|key| @config.delete(key) if empty?(@config[key]) }
        establish_connection
      end

      def find_user(jid)
        ActiveRecord::Base.clear_reloadable_connections!

        jid = JID.new(jid || '').bare.to_s
        return if jid.empty?
        xuser = by_jid(jid)
        return Vines::User.new(:jid => jid).tap do |user|
          user.name, user.password = xuser.name, xuser.password
          xuser.contacts.each do |contact|
            groups = contact.groups.map {|group| group.name }
            user.roster << Vines::Contact.new(
              :jid => contact.jid,
              :name => contact.name,
              :subscription => contact.subscription,
              :ask => contact.ask,
              :groups => groups)
          end
        end if xuser
      end
      defer :find_user

      def save_user(user)
        ActiveRecord::Base.clear_reloadable_connections!

        xuser = by_jid(user.jid) || Sql::User.new(:jid => user.jid.bare.to_s)
        xuser.name = user.name
        xuser.password = user.password

        # remove deleted contacts from roster
        xuser.contacts.delete(xuser.contacts.select do |contact|
          !user.contact?(contact.jid)
        end)

        # update contacts
        xuser.contacts.each do |contact|
          fresh = user.contact(contact.jid)
          contact.update_attributes(
            :name => fresh.name,
            :ask => fresh.ask,
            :subscription => fresh.subscription,
            :groups => groups(fresh))
        end

        # add new contacts to roster
        jids = xuser.contacts.map {|c| c.jid }
        user.roster.select {|contact| !jids.include?(contact.jid.bare.to_s) }
          .each do |contact|
            xuser.contacts.build(
              :user => xuser,
              :jid => contact.jid.bare.to_s,
              :name => contact.name,
              :ask => contact.ask,
              :subscription => contact.subscription,
              :groups => groups(contact))
          end
        xuser.save
      end
      defer :save_user

      def find_vcard(jid)
        ActiveRecord::Base.clear_reloadable_connections!

        jid = JID.new(jid || '').bare.to_s
        return if jid.empty?
        if xuser = by_jid(jid)
          Nokogiri::XML(xuser.vcard).root rescue nil
        end
      end
      defer :find_vcard

      def save_vcard(jid, card)
        ActiveRecord::Base.clear_reloadable_connections!

        xuser = by_jid(jid)
        if xuser
          xuser.vcard = card.to_xml
          xuser.save
        end
      end
      defer :save_vcard

      # Create the tables and indexes used by this storage engine.
      def create_schema(args={})
        ActiveRecord::Base.clear_reloadable_connections!

        args[:force] ||= false

        ActiveRecord::Schema.define do
          create_table :users, :force => args[:force] do |t|
            t.string :jid,      :limit => 1000, :null => false
            t.string :name,     :limit => 1000, :null => true
            t.string :password, :limit => 1000, :null => true
            t.text   :vcard,    :null => true
          end
          add_index :users, :jid, :unique => true

          create_table :contacts, :force => args[:force] do |t|
            t.integer :user_id,      :null => false
            t.string  :jid,          :limit => 1000, :null => false
            t.string  :name,         :limit => 1000, :null => true
            t.string  :ask,          :limit => 1000, :null => true
            t.string  :subscription, :limit => 1000, :null => false
          end
          add_index :contacts, [:user_id, :jid], :unique => true

          create_table :groups, :force => args[:force] do |t|
            t.string :name, :limit => 1000, :null => false
          end
          add_index :groups, :name, :unique => true

          create_table :contacts_groups, :id => false, :force => args[:force] do |t|
            t.integer :contact_id, :null => false
            t.integer :group_id,   :null => false
          end
          add_index :contacts_groups, [:contact_id, :group_id], :unique => true
        end
      end

      private

      def establish_connection
        ActiveRecord::Base.establish_connection(@config)
        # has_and_belongs_to_many requires a connection so configure the
        # associations here rather than in the class definitions above.
        Sql::Contact.has_and_belongs_to_many :groups
        Sql::Group.has_and_belongs_to_many :contacts
      end

      def by_jid(jid)
        jid = JID.new(jid).bare.to_s
        Sql::User.find_by_jid(jid, :include => {:contacts => :groups})
      end

      def groups(contact)
        contact.groups.map {|name| Sql::Group.find_or_create_by_name(name.strip) }
      end
    end
  end
end

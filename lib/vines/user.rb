# encoding: UTF-8

module Vines
  class User
    include Comparable

    attr_accessor :name, :password, :roster
    attr_reader :jid

    def initialize(args={})
      @jid = JID.new(args[:jid])
      raise ArgumentError, 'invalid jid' unless @jid.node && !@jid.domain.empty?
      @name = args[:name]
      @password = args[:password]
      @roster = args[:roster] || []
    end

    def <=>(user)
      self.jid.to_s <=> user.jid.to_s
    end

    def eql?(user)
      user.is_a?(User) && self == user
    end

    def hash
      jid.to_s.hash
    end

    # Update this user's information from the given user object.
    def update_from(user)
      @name = user.name
      @password = user.password
      @roster = user.roster.map {|c| c.clone }
    end

    # Return true if the jid is on this user's roster.
    def contact?(jid)
      !contact(jid).nil?
    end

    # Returns the contact with this jid or nil if not found.
    def contact(jid)
      bare = JID.new(jid).bare
      @roster.find {|c| c.jid.bare == bare }
    end

    # Returns true if the user is subscribed to this contact's
    # presence updates.
    def subscribed_to?(jid)
      contact = contact(jid)
      contact && contact.subscribed_to?
    end

    # Returns true if the user has a presence subscription from this contact.
    # The contact is subscribed to this user's presence.
    def subscribed_from?(jid)
      contact = contact(jid)
      contact && contact.subscribed_from?
    end

    # Removes the contact with this jid from the user's roster.
    def remove_contact(jid)
      bare = JID.new(jid).bare
      @roster.reject! {|c| c.jid.bare == bare }
    end

    # Returns a list of the contacts to which this user has
    # successfully subscribed.
    def subscribed_to_contacts
      @roster.select {|c| c.subscribed_to? }
    end

    # Returns a list of the contacts that are subscribed to this user's
    # presence updates.
    def subscribed_from_contacts
      @roster.select {|c| c.subscribed_from? }
    end

    # Update the contact's jid on this user's roster to signal that this user
    # has requested the contact's permission to receive their presence updates.
    def request_subscription(jid)
      unless contact = contact(jid)
        contact = Contact.new(:jid => jid)
        @roster << contact
      end
      contact.ask = 'subscribe' if %w[none from].include?(contact.subscription)
    end

    # Add the user's jid to this contact's roster with a subscription state of
    # 'from.' This signals that this contact has approved a user's subscription.
    def add_subscription_from(jid)
      unless contact = contact(jid)
        contact = Contact.new(:jid => jid)
        @roster << contact
      end
      contact.subscribe_from
    end

    def remove_subscription_to(jid)
      if contact = contact(jid)
        contact.unsubscribe_to
      end
    end

    def remove_subscription_from(jid)
      if contact = contact(jid)
        contact.unsubscribe_from
      end
    end

    # Returns this user's roster contacts as an iq query element.
    def to_roster_xml(id)
      doc = Nokogiri::XML::Document.new
      doc.create_element('iq', 'id' => id, 'type' => 'result') do |el|
        el << doc.create_element('query', 'xmlns' => 'jabber:iq:roster') do |query|
          @roster.sort!.each do |contact|
            query << contact.to_roster_xml
          end
        end
      end
    end
  end
end

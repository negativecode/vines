# encoding: UTF-8

module Vines
  class JID
    include Comparable

    PATTERN = /\A(?:([^@]*)@)??([^@\/]*)(?:\/(.*?))?\Z/.freeze

    # http://tools.ietf.org/html/rfc6122#appendix-A
    NODE_PREP = /[[:cntrl:] "&'\/:<>@]/.freeze

    # http://tools.ietf.org/html/rfc3454#appendix-C
    NAME_PREP = /[[:cntrl:] ]/.freeze

    attr_reader :node, :domain, :resource
    attr_writer :resource

    def self.new(node, domain=nil, resource=nil)
      node.is_a?(JID) ? node : super
    end

    def initialize(node, domain=nil, resource=nil)
      @node, @domain, @resource = node, domain, resource

      if @domain.nil? && @resource.nil?
        @node, @domain, @resource = @node.to_s.scan(PATTERN).first
      end
      [@node, @domain].each {|part| part.downcase! if part }

      validate
    end

    # Strip the resource part from this JID and return it as a new
    # JID object. The new JID contains only the optional node part
    # and the required domain part from the original. This JID remains
    # unchanged.
    def bare
      JID.new(@node, @domain)
    end

    # Return true if this is a bare JID without a resource part.
    def bare?
      @resource.nil?
    end

    # Return true if this is a domain-only JID without a node or resource part.
    def domain?
      !empty? && to_s == @domain
    end

    # Return true if this JID is equal to the empty string ''. That is, it's
    # missing the node, domain, and resource parts that form a valid JID. It
    # makes for easier error handling to be able to create JID objects from
    # strings and then check if they're empty rather than nil.
    def empty?
      to_s == ''
    end

    def <=>(jid)
      self.to_s <=> jid.to_s
    end

    def eql?(jid)
      jid.is_a?(JID) && self == jid
    end

    def hash
      self.to_s.hash
    end

    def to_s
      s = @domain
      s = "#{@node}@#{s}" if @node
      s = "#{s}/#{@resource}" if @resource
      s
    end

    private

    def validate
      [@node, @domain, @resource].each do |part|
        raise ArgumentError, 'jid too long' if (part || '').size > 1023
      end
      raise ArgumentError, 'empty node' if @node && @node.strip.empty?
      raise ArgumentError, 'node contains invalid characters' if @node && @node =~ NODE_PREP
      raise ArgumentError, 'empty resource' if @resource && @resource.strip.empty?
      raise ArgumentError, 'resource contains invalid characters' if @resource && @resource =~ NAME_PREP
      raise ArgumentError, 'empty domain' if @domain == '' && (@node || @resource)
      raise ArgumentError, 'domain contains invalid characters' if @domain && @domain =~ NAME_PREP
    end
  end
end

# encoding: UTF-8

module Vines
  class JID
    include Comparable

    PATTERN = /^(?:([^@]*)@)??([^@\/]*)(?:\/(.*?))?$/.freeze

    # http://tools.ietf.org/html/rfc6122#appendix-A
    NODE_PREP = /[[:space:][:cntrl:]"&'\/:<>@]/.freeze

    # http://tools.ietf.org/html/rfc3454#appendix-C
    NAME_PREP = /[[:space:][:cntrl:]]/.freeze

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

    def bare
      JID.new(@node, @domain)
    end

    def bare?
      @resource.nil?
    end

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

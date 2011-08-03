# encoding: UTF-8

module Vines
  class JID
    include Comparable

    PATTERN = /^(?:([^@]*)@)??([^@\/]*)(?:\/(.*?))?$/.freeze

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
      [@node, @domain].each {|piece| piece.downcase! if piece }

      [@node, @domain, @resource].each do |piece|
        raise ArgumentError, 'jid too long' if (piece || '').size > 1023
      end
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
  end
end

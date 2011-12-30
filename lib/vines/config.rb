# encoding: UTF-8

module Vines

  # A Config object is passed to the stream handlers to give them access
  # to server configuration information like virtual host names, storage
  # systems, etc. This class provides the DSL methods used in the
  # conf/config.rb file.
  class Config
    LOG_LEVELS = %w[debug info warn error fatal].freeze

    attr_reader :router, :vhosts

    @@instance = nil
    def self.configure(&block)
      @@instance = self.new(&block)
    end

    def self.instance
      @@instance
    end

    def initialize(&block)
      @vhosts, @ports, @cluster = {}, {}, nil
      @null = Storage::Null.new
      @router = Router.new(self)
      instance_eval(&block)
      raise "must define at least one virtual host" if @vhosts.empty?
    end

    def host(*names, &block)
      names = names.flatten.map {|name| name.downcase }
      dupes = names.uniq.size != names.size || (@vhosts.keys & names).any?
      raise "one host definition per domain allowed" if dupes
      names.each do |name|
        @vhosts[name] = Host.new(self, name, &block)
      end
    end

    %w[client server http component].each do |name|
      define_method(name) do |*args, &block|
        port = Vines::Config.const_get("#{name.capitalize}Port")
        raise "one #{name} port definition allowed" if @ports[name.to_sym]
        @ports[name.to_sym] = port.new(self, *args) do
          instance_eval(&block) if block
        end
      end
    end

    def cluster(&block)
      return @cluster unless block
      raise "one cluster definition allowed" if @cluster
      @cluster = Cluster.new(self, &block)
    end

    def log(level)
      const = Logger.const_get(level.to_s.upcase) rescue nil
      unless LOG_LEVELS.include?(level.to_s) && const
        raise "log level must be one of: #{LOG_LEVELS.join(', ')}"
      end
      Class.new.extend(Vines::Log).log.level = const
    end

    def ports
      @ports.values
    end

    # Return true if the domain is virtual hosted by this server.
    def vhost?(domain)
      @vhosts.key?(domain.to_s)
    end

    # Returns the storage system for the domain or a Storage::Null instance if
    # the domain is not hosted at this server.
    def storage(domain)
      host = @vhosts[domain.to_s]
      host ? host.storage : @null
    end

    # Returns the PubSub system for the domain or nil if pubsub is not enabled
    # for this domain.
    def pubsub(domain)
      host = @vhosts.values.find {|host| host.pubsub?(domain) }
      host.pubsubs[domain.to_s] if host
    end

    # Return true if the domain is a pubsub service hosted at a virtual host
    # at this server.
    def pubsub?(domain)
      @vhosts.values.any? {|host| host.pubsub?(domain) }
    end

    # Return true if all JIDs belong to components hosted by this server.
    def component?(*jids)
      !jids.flatten.index do |jid|
        !component_password(JID.new(jid).domain)
      end
    end

    # Return the password for the component or nil if it's not hosted here.
    def component_password(domain)
      host = @vhosts.values.find {|host| host.component?(domain) }
      host.password(domain) if host
    end

    # Return true if all of the JIDs are hosted by this server.
    def local_jid?(*jids)
      !jids.flatten.index do |jid|
        !vhost?(JID.new(jid).domain)
      end
    end

    # Return true if private XML fragment storage is enabled for this domain.
    def private_storage?(domain)
      host = @vhosts[domain.to_s]
      host.private_storage? if host
    end

    # Returns true if server-to-server connections are allowed with the
    # given domain.
    def s2s?(domain)
      @ports[:server] && @ports[:server].hosts.include?(domain.to_s)
    end

    # Return true if the server is a member of a cluster, serving the same
    # domains from different machines.
    def cluster?
      !!@cluster
    end

    # Retrieve the Port subclass with this name:
    # [:client, :server, :http, :component]
    def [](name)
      @ports[name] or raise ArgumentError.new("no port named #{name}")
    end

    # Return true if the two JIDs are allowed to send messages to each other.
    # Both domains must have enabled cross_domain_messages in their config files.
    def allowed?(to, from)
      to, from = JID.new(to), JID.new(from)
      return false                      if to.empty? || from.empty?
      return true                       if to.domain == from.domain # same domain always allowed
      return cross_domain?(to, from)    if local_jid?(to, from)     # both virtual hosted here
      return check_subdomains(to, from) if subdomain?(to, from)     # component/pubsub to component/pubsub
      return check_subdomain(to, from)  if subdomain?(to)           # to component/pubsub
      return check_subdomain(from, to)  if subdomain?(from)         # from component/pubsub
      return cross_domain?(to)          if local_jid?(to)           # from is remote
      return cross_domain?(from)        if local_jid?(from)         # to is remote
      return false
    end

    private

    # Return true if all of the JIDs are some kind of subdomain resource hosted
    # here (either a component or a pubsub domain).
    def subdomain?(*jids)
      !jids.flatten.index do |jid|
        !component?(jid) && !pubsub?(jid)
      end
    end

    # Return true if the third-level subdomain JIDs (components and pubsubs)
    # are allowed to communicate with each other. For example, a
    # tea.wonderland.lit component should be allowed to send messages to
    # pubsub.wonderland.lit because they share the second-level wonderland.lit
    # domain.
    def check_subdomains(to, from)
      sub1, sub2 = strip_domain(to), strip_domain(from)
      (sub1 == sub2) || cross_domain?(sub1, sub2)
    end

    # Return true if the third-level subdomain JID (component or pubsub) is
    # allowed to communicate with the other JID. For example,
    # pubsub.wonderland.lit should be allowed to send messages to
    # alice@wonderland.lit because they share the second-level wonderland.lit
    # domain.
    def check_subdomain(subdomain, jid)
      comp = strip_domain(subdomain)
      return true if comp.domain == jid.domain
      local_jid?(jid) ? cross_domain?(comp, jid) : cross_domain?(comp)
    end

    # Return the third-level JID's domain with the first subdomain stripped off
    # to create a second-level domain. For example, alice@tea.wonderland.lit
    # returns wonderland.lit.
    def strip_domain(jid)
      domain = jid.domain.split('.').drop(1).join('.')
      JID.new(domain)
    end

    # Return true if all JIDs are allowed to exchange cross domain messages.
    def cross_domain?(*jids)
      !jids.flatten.index do |jid|
        !@vhosts[jid.domain].cross_domain_messages?
      end
    end
  end
end

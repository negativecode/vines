# encoding: UTF-8

module Vines
  module Command
    class Init
      def run(opts)
        raise 'vines init <domain>' unless opts[:args].size == 1
        domain = opts[:args].first
        dir = File.expand_path(domain)
        raise "Directory already initialized: #{domain}" if File.exists?(dir)
        Dir.mkdir(dir)

        %w[conf web].each do |sub|
          FileUtils.cp_r(File.expand_path("../../../../#{sub}", __FILE__), dir)
        end
        users, log, pid = %w[data/users log pid].map do |sub|
          File.join(dir, sub).tap {|subdir| FileUtils.makedirs(subdir) }
        end

        create_users(domain, users)
        update_config(domain, File.join(dir, 'conf', 'config.rb'))
        fix_perms(dir)
        Command::Cert.new.create_cert(domain, File.join(dir, 'conf/certs'))

        puts "Initialized server directory: #{domain}"
        puts "Run 'cd #{domain} && vines start' to begin"
      end

      private

      # Limit file system database directory access so the server is the only
      # process managing the data. The config.rb file contains component and
      # database passwords, so restrict access to just the server user as well.
      def fix_perms(dir)
        %w[data data/users].each do |f|
          File.chmod(0700, File.join(dir, f))
        end
        File.chmod(0600, File.join(dir, 'conf/config.rb'))
      end

      def update_config(domain, config)
        text = File.read(config)
        File.open(config, 'w') do |f|
          f.write(text.gsub('wonderland.lit', domain.downcase))
        end
      end

      def create_users(domain, dir)
        password = 'secr3t'
        alice, arthur = %w[alice arthur].map do |jid|
          User.new(:jid => [jid, domain.downcase].join('@'),
            :password => BCrypt::Password.create(password).to_s)
        end

        [[alice, arthur], [arthur, alice]].each do |user, contact|
          user.roster  << Contact.new(
            :jid => contact.jid,
            :name => contact.jid.node.capitalize,
            :subscription => 'both',
            :groups => %w[Buddies])
        end

        storage = Storage::Local.new { dir(dir) }
        [alice, arthur].each do |user|
          storage.save_user(user)
          puts "Created example user #{user.jid} with password #{password}"
        end
      end
    end
  end
end
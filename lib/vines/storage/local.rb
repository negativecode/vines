# encoding: UTF-8

module Vines
  class Storage

    # A storage implementation that persists data to YAML files on the
    # local file system.
    class Local < Storage
      register :fs

      def initialize(&block)
        @dir = nil
        instance_eval(&block)
        unless @dir && File.directory?(@dir) && File.writable?(@dir)
          raise 'Must provide a writable storage directory'
        end

        %w[user vcard fragment].each do |sub|
          sub = File.expand_path(sub, @dir)
          Dir.mkdir(sub, 0700) unless File.exists?(sub)
        end
      end

      def dir(dir=nil)
        dir ? @dir = File.expand_path(dir) : @dir
      end

      def find_user(jid)
        jid = JID.new(jid).bare.to_s
        file = "user/#{jid}" unless jid.empty?
        record = YAML.load(read(file)) rescue nil
        return User.new(jid: jid).tap do |user|
          user.name, user.password = record.values_at('name', 'password')
          (record['roster'] || {}).each_pair do |jid, props|
            user.roster << Contact.new(
              jid: jid,
              name: props['name'],
              subscription: props['subscription'],
              ask: props['ask'],
              groups: props['groups'] || [])
          end
        end if record
      end

      def save_user(user)
        record = {'name' => user.name, 'password' => user.password, 'roster' => {}}
        user.roster.each do |contact|
          record['roster'][contact.jid.bare.to_s] = contact.to_h
        end
        save("user/#{user.jid.bare}", YAML.dump(record))
      end

      def find_vcard(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        file = "vcard/#{jid}"
        Nokogiri::XML(read(file)).root rescue nil
      end

      def save_vcard(jid, card)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        save("vcard/#{jid}", card.to_xml)
      end

      def find_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        file = 'fragment/%s' % fragment_id(jid, node)
        Nokogiri::XML(read(file)).root rescue nil
      end

      def save_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        file = 'fragment/%s' % fragment_id(jid, node)
        save(file, node.to_xml)
      end

      private

      def absolute_path(file)
        File.expand_path(file, @dir).tap do |absolute|
          parent = File.dirname(File.dirname(absolute))
          raise 'path traversal' unless parent == @dir
        end
      end

      def read(file)
        file = absolute_path(file)
        File.read(file, encoding: 'utf-8')
      end

      def save(file, content)
        file = absolute_path(file)
        File.open(file, 'w:utf-8') {|f| f.write(content) }
        File.chmod(0600, file)
      end

      def fragment_id(jid, node)
        id = Digest::SHA1.hexdigest("#{node.name}:#{node.namespace.href}")
        "#{jid}-#{id}"
      end
    end
  end
end

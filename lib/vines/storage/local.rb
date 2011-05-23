# encoding: UTF-8

module Vines
  class Storage

    # A storage implementation that persists data to YAML files on the
    # local file system.
    class Local < Storage
      register :fs

      def initialize(&block)
        instance_eval(&block)
        unless @dir && File.directory?(@dir) && File.writable?(@dir)
          raise 'Must provide a writable storage directory'
        end
      end

      def dir(dir=nil)
        dir ? @dir = File.expand_path(dir) : @dir
      end

      def find_user(jid)
        jid = JID.new(jid || '').bare.to_s
        file = File.join(@dir, "#{jid}.user") unless jid.empty?
        record = YAML.load_file(file) rescue nil
        return User.new(:jid => jid).tap do |user|
          user.name, user.password = record.values_at('name', 'password')
          (record['roster'] || {}).each_pair do |jid, props|
            user.roster << Contact.new(
              :jid => jid,
              :name => props['name'],
              :subscription => props['subscription'],
              :ask => props['ask'],
              :groups => props['groups'] || [])
          end
        end if record
      end

      def save_user(user)
        record = {'name' => user.name, 'password' => user.password, 'roster' => {}}
        user.roster.each do |contact|
          record['roster'][contact.jid.bare.to_s] = contact.to_h
        end
        file = File.join(@dir, "#{user.jid.bare.to_s}.user")
        File.open(file, 'w') do |f|
          YAML.dump(record, f)
        end
      end

      def find_vcard(jid)
        jid = JID.new(jid || '').bare.to_s
        return if jid.empty?
        file = File.join(@dir, "#{jid}.vcard")
        Nokogiri::XML(File.read(file)).root rescue nil
      end

      def save_vcard(jid, card)
        jid = JID.new(jid).bare.to_s
        file = File.join(@dir, "#{jid}.vcard")
        File.open(file, 'w') do |f|
          f.write(card.to_xml)
        end
      end

      def find_fragment(jid, node)
        jid = JID.new(jid || '').bare.to_s
        return if jid.empty?
        file = File.join(@dir, fragment_id(jid, node))
        Nokogiri::XML(File.read(file)).root rescue nil
      end

      def save_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        file = File.join(@dir, fragment_id(jid, node))
        File.open(file, 'w') do |f|
          f.write(node.to_xml)
        end
      end

      private

      def fragment_id(jid, node)
        id = Digest::SHA1.hexdigest("#{node.name}:#{node.namespace.href}")
        "#{jid}-#{id}.fragment"
      end
    end
  end
end

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

        %w[user vcard fragment room message].each do |sub|
          sub = File.expand_path(sub, @dir)
          Dir.mkdir(sub, 0700) unless File.exists?(sub)
        end
      end

      def dir(dir=nil)
        dir ? @dir = File.expand_path(dir) : @dir
      end

      def find_user(jid)
        jid = JID.new(jid).bare.to_s
        file = absolute_path("user/#{jid}") unless jid.empty?
        record = YAML.load_file(file) rescue nil
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
        save("user/#{user.jid.bare}") do |f|
          YAML.dump(record, f)
        end
      end

      def offline_messages_present?(jid)
        File.exist?(absolute_path("message/#{jid.bare.to_s}"))
      end

      def delete_offline_messages(jid)
        if offline_messages_present?(jid)
          File.delete(absolute_path("message/#{jid.bare.to_s}"))
        end
      end

      def fetch_offline_messages(jid)
        jid = JID.new(jid).bare.to_s        
        file = absolute_path("message/#{jid}") unless jid.empty?        
        offline_msgs = YAML.load_file(file) rescue {}
      end

      def save_offline_message(msg)
        file = "message/#{msg[:to]}"
        offline_msgs = YAML.load_file(absolute_path(file)) rescue []
        msg.delete('to')
        offline_msgs << msg
        save(file) do |f|          
          YAML.dump(offline_msgs,f)
        end
      end

      def find_vcard(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        file = absolute_path("vcard/#{jid}")
        Nokogiri::XML(File.read(file)).root rescue nil
      end

      def save_vcard(jid, card)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        save("vcard/#{jid}") do |f|
          f.write(card.to_xml)
        end
      end

      def find_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        file = absolute_path("fragment/#{fragment_id(jid, node)}")
        Nokogiri::XML(File.read(file)).root rescue nil
      end

      def save_fragment(jid, node)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        save("fragment/#{fragment_id(jid, node)}") do |f|
          f.write(node.to_xml)
        end
      end

      private

      def absolute_path(file)
        File.expand_path(file, @dir).tap do |absolute|
          parent = File.dirname(File.dirname(absolute))
          raise "path traversal failed for #{file}" unless parent == @dir
        end
      end

      def save(file)
        file = absolute_path(file)
        File.open(file, 'w') {|f| yield f }
        File.chmod(0600, file)
      end

      def fragment_id(jid, node)
        id = Digest::SHA1.hexdigest("#{node.name}:#{node.namespace.href}")
        "#{jid}-#{id}"
      end
    end
  end
end

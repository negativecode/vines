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

        %w[user vcard fragment delayed_message].each do |sub|
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

      def delay_message(jid, message)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?
        # Add delay element http://xmpp.org/extensions/xep-0203.html#schema
        doc = Nokogiri::XML::Document.new
        delay = doc.create_element('delay',
                                  'xmlns' => 'urn:xmpp:delay',
                                  'from'  => message['from'],
                                  'stamp' => Time.now.strftime('%Y-%m-%dT%H:%M:%SZ'))
        message = message.clone
        message.add_child(delay)
        file = absolute_path('delayed_message/%s-%s' % [jid, message['id']])
        save(file, message.to_xml)
      end

      def fetch_delayed_messages(jid)
        jid = JID.new(jid).bare.to_s
        return if jid.empty?

        messages = []
        Dir[absolute_path('delayed_message/%s-*' % jid)].each do |file|
          messages << Nokogiri::XML(read(file)).root rescue nil
          File.delete(file)
        end
        messages
      end

      private

      # Resolves a relative file name into an absolute path inside the
      # storage directory.
      #
      # file - A fully-qualified or relative file name String.
      #
      # Returns the fully-qualified file path String.
      #
      # Raises RuntimeError if the resolved path is outside of the storage
      # directory. This prevents directory path traversals with maliciously
      # crafted JIDs.
      def absolute_path(file)
        File.expand_path(file, @dir).tap do |absolute|
          parent = File.dirname(File.dirname(absolute))
          raise 'path traversal' unless parent == @dir
        end
      end

      # Read the file from the filesystem and return its contents as a String.
      # All files are assumed to be encoded as UTF-8.
      #
      # file - A fully-qualified or relative file name String.
      #
      # Returns the file content as a UTF-8 encoded String.
      def read(file)
        file = absolute_path(file)
        File.read(file, encoding: 'utf-8')
      end

      # Write the content to the file. Make sure to consistently encode files
      # we read and write as UTF-8.
      #
      # file    - A fully-qualified or relative file name String.
      # content - The String to write.
      #
      # Returns nothing.
      def save(file, content)
        file = absolute_path(file)
        File.open(file, 'w:utf-8') {|f| f.write(content) }
        File.chmod(0600, file)
      end

      # Generates a unique file id for the user's private XML fragment.
      #
      # Private XML fragment storage needs to uniquely identify fragment files
      # on disk. We combine the user's JID with a SHA-1 hash of the element's
      # name and namespace to avoid special characters in the file name.
      #
      # jid  - A bare JID identifying the user who owns this fragment.
      # node - A Nokogiri::XML::Node for the XML to be stored.
      #
      # Returns an id String suitable for use in a file name.
      def fragment_id(jid, node)
        id = Digest::SHA1.hexdigest("#{node.name}:#{node.namespace.href}")
        "#{jid}-#{id}"
      end
    end
  end
end

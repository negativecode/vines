class @Transfer
  constructor: (options) ->
    @session  = options.session
    @file     = options.file
    @to       = options.to
    @progress = options.progress
    @complete = options.complete
    @chunks   = new Chunks @file
    @opened   = false
    @closed   = false
    @sid      = @session.uniqueId()
    @seq      = 0
    @sent     = 0

  start: ->
    node = $("""
      <iq id="#{@session.uniqueId()}" to="#{@to}" type="set">
        <si xmlns="http://jabber.org/protocol/si" id="#{@session.uniqueId()}" profile="http://jabber.org/protocol/si/profile/file-transfer">
          <file xmlns="http://jabber.org/protocol/si/profile/file-transfer" name="" size="#{@file.size}"/>
          <feature xmlns="http://jabber.org/protocol/feature-neg">
            <x xmlns="jabber:x:data" type="form">
              <field var="stream-method" type="list-single">
                <option><value>http://jabber.org/protocol/ibb</value></option>
              </field>
            </x>
          </feature>
        </si>
      </iq>
    """)
    $('file', node).attr 'name', @file.name

    @session.sendIQ node.get(0), (result) =>
      methods = $('si feature x field[var="stream-method"] value', result)
      ok = (true for m in methods when $(m).text() == 'http://jabber.org/protocol/ibb').length > 0
      this.open() if ok

  open: ->
    node = $("""
      <iq id="#{@session.uniqueId()}" to="#{@to}" type="set">
        <open xmlns="http://jabber.org/protocol/ibb" sid="#{@sid}" block-size="4096"/>
      </iq>
    """)
    @session.sendIQ node.get(0), (result) =>
      if this.ok result
        @opened = true
        this.sendChunk()

  sendChunk: ->
    return if @closed
    @chunks.chunk (chunk) =>
      unless chunk
        this.close()
        return

      node = $("""
        <iq id="#{@session.uniqueId()}" to="#{@to}" type="set">
          <data xmlns="http://jabber.org/protocol/ibb" sid="#{@sid}" seq="#{@seq++}">#{chunk}</data>
        </iq>
      """)
      @seq = 0 if @seq > 65535

      @session.sendIQ node.get(0), (result) =>
        return unless this.ok result
        pct = Math.ceil ++@sent / @chunks.total * 100
        this.progress pct
        this.sendChunk()

  close: ->
    return if @closed
    @closed = true
    node = $("""
      <iq id="#{@session.uniqueId()}" to="#{@to}" type="set">
        <close xmlns="http://jabber.org/protocol/ibb" sid="#{@sid}"/>
      </iq>
    """)
    @session.sendIQ node.get(0), ->
    this.complete()

  stop: ->
    if @opened
      this.close()
    else
      this.complete()

  ok: (result) -> $(result).attr('type') == 'result'

  class Chunks
    CHUNK_SIZE = 3 / 4 * 4096

    constructor: (@file) ->
      @total = Math.ceil @file.size / CHUNK_SIZE
      @slice = @file.slice || @file.webkitSlice || @file.mozSlice
      @pos   = 0

    chunk: (callback) ->
      start = @pos
      end   = @pos + CHUNK_SIZE
      @pos  = end
      if start > @file.size
        callback null
      else
        chunk = @slice.call @file, start, end
        reader = new FileReader()
        reader.onload = (event) ->
          callback btoa event.target.result
        reader.readAsBinaryString chunk

class Transfer
  constructor: (options) ->
    @session  = options.session
    @file     = options.file
    @to       = options.to
    @progress = options.progress
    @complete = options.complete
    @chunks   = new Chunks(@file)
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

    callback = (result) =>
      methods = $('si feature x field[var="stream-method"] value', result)
      ok = (true for m in methods when $(m).text() == 'http://jabber.org/protocol/ibb').length > 0
      this.open() if ok

    @session.sendIQ node.get(0), callback

  open: ->
    node = $("""
      <iq id="#{@session.uniqueId()}" to="#{@to}" type="set">
        <open xmlns="http://jabber.org/protocol/ibb" sid="#{@sid}" block-size="4096"/>
      </iq>
    """)
    callback = (result) =>
      if this.ok result
        @opened = true
        @chunks.start => this.sendChunk()
    @session.sendIQ node.get(0), callback

  sendChunk: ->
    return if @closed
    unless chunk = @chunks.chunk()
      this.close()
      return

    node = $("""
      <iq id="#{@session.uniqueId()}" to="#{@to}" type="set">
        <data xmlns="http://jabber.org/protocol/ibb" sid="#{@sid}" seq="#{@seq++}">#{chunk}</data>
      </iq>
    """)
    @seq = 0 if @seq > 65535
    callback = (result) =>
      return unless this.ok result
      pct = Math.ceil ++@sent / @chunks.total * 100
      this.progress pct
      this.sendChunk()
    @session.sendIQ node.get(0), callback

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
    constructor: (@file) ->
      @chunks = []
      @total  = 0

    chunk: -> @chunks.shift()

    start: (callback) ->
      reader = new FileReader()
      reader.onload = (event) =>
        data = btoa event.target.result
        @chunks = (chunk for chunk in data.split /(.{1,4096})/ when chunk)
        @total = @chunks.length
        callback()
      reader.readAsBinaryString @file

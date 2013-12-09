# Welcome to Vines

Vines is an XMPP chat server that supports thousands of simultaneous connections,
using EventMachine for asynchronous IO. User data is stored in a
[SQL database](https://github.com/negativecode/vines-sql),
[CouchDB](https://github.com/negativecode/vines-couchdb),
[MongoDB](https://github.com/negativecode/vines-mongodb),
[Redis](https://github.com/negativecode/vines-redis), the file system, or a
custom storage implementation that you provide. LDAP authentication can be used
so user names and passwords aren't stored in the chat database. SSL encryption
is mandatory on all client and server connections.

The server includes support for web chat clients, using BOSH (XMPP over HTTP). A
sample web application is available in the
[vines-web](https://github.com/negativecode/vines-web) gem.

Additional documentation can be found at [getvines.org](http://www.getvines.org/).

## Usage

```
$ gem install vines
$ vines init wonderland.lit
$ cd wonderland.lit && vines start
```

Login with your favorite chat program (iChat, Adium, Pidgin, etc.) to start chatting!

## Dependencies

Vines requires Ruby 1.9.3 or better. Instructions for installing the
needed OS packages, as well as Ruby itself, are available at
http://www.getvines.org/ruby.

## Development

```
$ script/bootstrap
$ script/tests
```

## Standards support

Vines implements the full XMPP specs in [RFC 6120](http://www.rfc-editor.org/rfc/rfc6120.txt)
and [RFC 6121](http://www.rfc-editor.org/rfc/rfc6121.txt). It also implements
the following extensions.

- [XEP-0030](https://xmpp.org/extensions/xep-0030.html) Service Discovery
- [XEP-0049](https://xmpp.org/extensions/xep-0049.html) Private XML Storage
- [XEP-0054](https://xmpp.org/extensions/xep-0054.html) vcard-temp
- [XEP-0060](https://xmpp.org/extensions/xep-0060.html) Publish-Subscribe
- [XEP-0092](https://xmpp.org/extensions/xep-0092.html) Software Version
- [XEP-0114](https://xmpp.org/extensions/xep-0114.html) Component Protocol
- [XEP-0124](https://xmpp.org/extensions/xep-0124.html) Bidirectional-streams Over Synchronous HTTP (BOSH)
- [XEP-0199](https://xmpp.org/extensions/xep-0199.html) XMPP Ping
- [XEP-0206](https://xmpp.org/extensions/xep-0206.html) XMPP Over BOSH

## Contact

* David Graham <david@negativecode.com>

## License

Vines is released under the MIT license. Check the LICENSE file for details.

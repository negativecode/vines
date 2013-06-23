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

## Contact

* David Graham <david@negativecode.com>

## License

Vines is released under the MIT license. Check the LICENSE file for details.

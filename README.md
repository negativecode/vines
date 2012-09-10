# Welcome to Vines

Vines is an XMPP chat server that supports thousands of simultaneous connections,
using EventMachine for asynchronous IO. User data is stored in a SQL database,
CouchDB, MongoDB, Redis, the file system, or a custom storage implementation
that you provide. LDAP authentication can be used so user names and passwords
aren't stored in the chat database. SSL encryption is mandatory on all client
and server connections.

The Vines XMPP server includes a web chat client. The web application is available
after starting the chat server at http://localhost:5280/chat/.

Additional documentation can be found at www.getvines.org.

## Usage

```
$ gem install vines
$ vines init wonderland.lit
$ cd wonderland.lit && vines start
$ open http://localhost:5280/chat/
```

Login with your favorite chat program (iChat, Adium, Pidgin, etc.) to start chatting!

## Dependencies

Vines requires Ruby 1.9.2 or better. Instructions for installing the
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

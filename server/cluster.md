---
layout: docs
title: Vines - Cluster
---
## Clustering

Two or more Vines server instances can be clustered together to handle load-balancing and high-availability. The instances use an in-memory Redis database to communicate with one another.

<pre>
cluster do
  host 'redis.wonderland.lit'
  port 6379
end
</pre>

Make sure that all members of the cluster have identical conf/config.rb files. We don't want one member serving different chat domains with different settings than the others.

By using a common Redis database as the meeting place for all cluster nodes, we don't need to configure each node to tell it the location of the others. We just point them all at Redis and they discover each other automatically.

Also, each member doesn't need to open a connection to every other member to route messages to them. They each open a single connection to Redis and send messages to each other using pubsub channels.

Basically, Redis lets us build and configure a two dozen node cluster as easily as two nodes.

## BOSH/HTTP Clients

Web applications can connect to the chat server by tunneling the XMPP protocol through HTTP, using a technique called [BOSH](http://en.wikipedia.org/wiki/BOSH). Here's the conf/config.rb snippet that enables the Vines HTTP server.

<pre>
http '0.0.0.0', 5280 do
  bind '/xmpp'
  max_stanza_size 65536
  max_resources_per_account 5
  root 'web'
  vroute 'v1'
end
</pre>

The _vroute_ setting defines the value of the vroute cookie sent in each response that uniquely identifies this Vines HTTP server. Reverse proxy servers can use this cookie to implement sticky sessions.

It's important that each Vines server in the cluster have a unique vroute cookie value, so the proxy can choose the correct backend server to handle a request. If we have a three node cluster, we might give each instance a vroute value of v1, v2, and v3. The value is arbitrary, it just needs to be unique for each node.

If vroute is not set, and the server is clustered, a warning is logged at startup. This lets us know that HTTP clients may not work properly unless we've configured the proxy server itself to provide sticky session cookies.

<pre>
WARN -- vines: vroute sticky session cookie not set
</pre>

## Reverse Proxies & Sticky Sessions

The configuration above allows web browsers to connect directly to a Vines HTTP server. However, when we're running multiple Vines instances, we need to place a reverse proxy&mdash;like nginx, Apache mod_proxy, or HAProxy&mdash;in front of our Vines HTTP cluster.  The example below uses nginx, but any of the three proxies will work.

Whichever proxy we're using, it's important to configure it to use sticky sessions (a.k.a. session affinity). Once a client has established a chat session with a backend Vines server, all future requests for that session must be sent to the same backend.

The proxy will detect when a backend Vines server goes down and route future requests to the other cluster nodes. This allows the client to reconnect and establish a new session with a working backend.

Here's a working nginx.conf snippet that configures a reverse proxy to three Vines servers, using the vroute cookie to implement sticky sessions.

<pre>
# vines server backends
upstream xmpp {
  server 10.0.0.10:5280;
  server 10.0.0.11:5280;
  server 10.0.0.12:5280;
}

# sticky bosh session based on vroute cookie
map $cookie_vroute $sticky {
  default   xmpp;
  v1        10.0.0.10:5280;
  v2        10.0.0.11:5280;
  v3        10.0.0.12:5280;
}

server {
  listen 80;
  server_name wonderland.lit;
  root /home/vines/wonderland.lit/web;

  # proxy bosh requests to vines backends with sticky sessions
  location /xmpp {
    proxy_set_header      Host $http_host;
    proxy_redirect        off;
    proxy_connect_timeout 5;
    proxy_buffering       off;
    proxy_pass            http://$sticky$uri;
    proxy_read_timeout    70;
    keepalive_timeout     70;
    send_timeout          70;
    error_page            502 = @xmpp_fallback;
  }

  # sticky session backend down, choose new bosh backend to
  # which clients can reconnect
  location @xmpp_fallback {
    proxy_set_header      Host $http_host;
    proxy_next_upstream   error timeout http_500 http_502 http_503 http_504;
    proxy_redirect        off;
    proxy_connect_timeout 5;
    proxy_buffering       off;
    proxy_pass            http://xmpp;
  }
}
</pre>

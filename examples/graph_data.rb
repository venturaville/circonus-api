#!/usr/bin/env ruby
# Query Circonus data (uses official API not the one the javascript uses)
#

require 'rubygems'
require 'circonus'

require 'pp'
apikey="myapikey"
server="api.circonus.com"
appname="curl"
@c = Circonus.new(apikey,appname)
@c.set_server(server)
pp @a.get_graph_data('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')



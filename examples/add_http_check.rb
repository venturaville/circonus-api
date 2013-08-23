#!/usr/bin/env ruby
#
# Add an HTTP site check
#

require 'rubygems'
require 'optparse'
require 'circonus'
require "#{ENV['HOME']}/.circonus.rb"
@c = Circonus.new(@apitoken,@appname,@agent)

options = {}
options[:multi] = false
OptionParser.new { |opts|
  opts.banner = "Usage: #{File.basename($0)} [-h] [-m] sitename URL"
  opts.on( '-h', '--help', "This usage menu") do
    puts opts
    print "sitename = The site's hostname\n"
    print "URL = The actual url to check on the site\n"
    exit
  end
  opts.on( '-m','--multi',"Use multiple circonus brokers" ) do
    options[:multi] = true
  end
}.parse!


def usage()
  print <<EOF
  Usage: add_http_check.rb sitename URL
    -h,--help        This usage menu
    -m,--multi       Use multiple circonus brokers
EOF
end

sitename = ARGV[0]
url = ARGV[1]

circonus_brokers = @c.search_broker("circonus",'_type')
circonus_brokers = circonus_brokers.select {|a| a['_name'] != 'HTTPTrap'} # filter out http trap broker...
agentids = circonus_brokers.map { |m| m['_cid'] }
agentids = agentids[0,1] unless options[:multi]

bundle_stub = {
  "brokers"=>[ ],
  "display_name"=>nil,
  "period"=>60,
  "target"=>nil,
  "timeout"=>10,
  "type"=>"http",
  "metrics"=> [
    {"name"=>"body_match", "type"=>"text"},
    {"name"=>"bytes", "type"=>"numeric"},
    {"name"=>"code", "type"=>"text"},
    {"name"=>"duration", "type"=>"numeric"},
    {"name"=>"truncated", "type"=>"numeric"},
    {"name"=>"tt_connect", "type"=>"numeric"},
    {"name"=>"tt_firstbyte", "type"=>"numeric"}
  ],
  "config" => {
    "url"=>nil,
    "http_version"=>"1.1",
    "header_Host"=>nil,
    "read_limit"=>"1048576",
    "method"=>"GET",
    "code"=>"^200$",
    "redirects"=>"0"
  }
}

bundle = bundle_stub.clone
bundle['brokers'] = agentids
bundle['target'] = sitename
bundle['display_name'] = "#{sitename} http"
bundle['config']['url'] = url
bundle['config']['header_Host'] = sitename

search_bundles = @c.search_check_bundle(bundle['display_name'],'display_name')
if search_bundles.any? # already exists...
  r = @c.update_check_bundle(search_bundles.first['_cid'],bundle)
else
  r = @c.add_check_bundle(bundle)
end
if not r.nil? then
  print "Success\n"
  #pp r
end


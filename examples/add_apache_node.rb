#!/usr/bin/env ruby
# Add a single apache host to circonus

require 'rubygems'
require 'circonus'
require 'optparse'
require "#{ENV['HOME']}/.circonus.rb"

def do_update_check_bundle(data)
  search_check_bundle = @c.list_check_bundle({'display_name' => data['display_name']})
  existing = false
  if search_check_bundle.any? # already exists...
    existing = true
    r = @c.update_check_bundle(search_check_bundle.first['_cid'],data)
  else
    r = @c.add_check_bundle(data)
  end
  if not r.nil? then
    pp r
    print "Success (#{existing ? 'updating' : 'adding'} #{data['display_name']})\n"
  end
end


options = {}
options[:tags] = []
OptionParser.new { |opts|
  opts.banner = "Usage: #{File.basename($0)} [-h] hostname [-t tag1,tag2,...]\n"
  opts.on( '-h', '--help', "This usage menu") do
    puts opts
    exit
  end
  opts.on( '-t','--tags TAGLIST',"Apply comma separated list of tags" ) do |t|
    options[:tags] += t.split(/,/)
  end
}.parse!

def usage()
  print <<EOF
  Usage: #{File.basename($0)} hostname [-t tag1,tag2,... ]
    -h,--help        This usage menu
    -t,--tags        Comma separated list of tag names to apply (default is an empty list)
EOF
end

host = ARGV[0]
if host.nil? then
  usage()
  exit -1
end

@c = Circonus.new(@apitoken,@appname,@agent)

agents = @c.list_broker
agentid = agents.select { |a| a['_name'] == @agent }.first['_cid']

print "Adding apache for host #{host}\n"
data = {
  :agent_id => agentid,
  :target => host,
  :module => "apache",
}
bundle = {
  "type" => "http",
  "target" => host,
  "tags" => options[:tags],
  "timeout" => 10,
  "period" => 60,
  "display_name" => "#{host} http:apache",
  "brokers" => [
    agentid
  ],
  "metrics" => [
  ],
  "config" => {
    "code"=>"^200$",
    "extract"=>"^([\\w\\s]+):\\s*(\\S{1,30})\\r?\\n",
    "header_Host"=>host,
    "http_version"=>"1.1",
    "method"=>"GET",
    "read_limit"=>"1048576",
    "redirects"=>"0",
    "url"=>"http://#{host}/server-status?auto"
  }
}
%w{ code }.each do |metric|
  bundle['metrics'] << {
    'type' => 'text',
    'name' => metric
  }
end
%w{ code truncated tt_firstbyte BusyWorkers bytes duration tt_connect IdleWorkers }.each do |metric|
  bundle['metrics'] << {
    'type' => 'numeric',
    'name' => metric
  }
end

do_update_check_bundle(bundle)


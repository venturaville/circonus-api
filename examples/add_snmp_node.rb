#!/usr/bin/env ruby
# Add a single snmp based host to circonus

require 'rubygems'
require 'circonus'
require 'snmp'
require 'pp'
require 'optparse'


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
  Usage: add_snmp_node.rb hostname [-t tag1,tag2,... ]
    -h,--help        This usage menu
    -t,--tags        Comma separated list of tag names to apply (default is an empty list)
EOF
end

host = ARGV[0]
if host.nil? then
  usage()
  exit -1
end


# Make a guess as to what ethernet interface to query for data
def get_ethernet_oids(host)
  ifTable_columns = ["ifDescr", "ifOutOctets","ifIndex"]
  eth_name = nil
  eth_octets = nil
  eth_index = nil
  SNMP::Manager.open(:Host => host) do |manager|
    manager.walk(ifTable_columns) do |row|
      next if row[0].value.to_s.match('^lo')
      if eth_name.nil? then
        eth_name = row[0].value
        eth_octets = row[1].value
        eth_index = row[2].value
      end
      if row[1].value > eth_octets then
        eth_name = row[0].value
        eth_octets = row[1].value
        eth_index = row[2].value
      end
    end
  end
  if eth_index.nil?
    eth_index = 0
  end
  return {
    "ifOutOctets" => ".1.3.6.1.2.1.2.2.1.16.#{eth_index}",
    "ifInOctets" => ".1.3.6.1.2.1.2.2.1.10.#{eth_index}"
  }
end

require "#{ENV['HOME']}/.circonus.rb"
@c = Circonus.new(@apitoken,@appname,@agent)

agentid = @c.search_broker(@agent,'_name').first['_cid']

print "Adding snmp check for host #{host}\n"
data_stub = {
  "type" => nil,
  "target" => nil,
  "timeout" => 10,
  "period" => 60,
  "display_name" => nil,
  "brokers" => [],
  "metrics" => [],
  "config" => {}
}
bundle = data_stub.clone()
bundle['tags'] = options[:tags]
bundle['target'] = host
bundle['type'] = 'snmp'
bundle['display_name'] = "#{host} snmp"
bundle['brokers'] << agentid
bundle['config'] = {
  "community" => "public",
  "version" => "2c",
  "port" => "161",
}
oids = {
  "memAvailSwap"=> ".1.3.6.1.4.1.2021.4.4.0",
  "memAvailReal"=> ".1.3.6.1.4.1.2021.4.6.0",
  "memTotalSwap"=> ".1.3.6.1.4.1.2021.4.3.0",
  "memTotalReal"=> ".1.3.6.1.4.1.2021.4.5.0",
  "memTotalFree"=> ".1.3.6.1.4.1.2021.4.11.0",
  "memShared"=> ".1.3.6.1.4.1.2021.4.13.0",
  "memBuffer"=> ".1.3.6.1.4.1.2021.4.14.0",
  "memCached"=> ".1.3.6.1.4.1.2021.4.15.0",
  "ssCpuRawUser"=> ".1.3.6.1.4.1.2021.11.50.0",
  "ssCpuRawNice"=> ".1.3.6.1.4.1.2021.11.51.0",
  "ssCpuRawSystem"=> ".1.3.6.1.4.1.2021.11.52.0",
  "ssCpuRawIdle"=> ".1.3.6.1.4.1.2021.11.53.0",
  "ssCpuRawWait"=> ".1.3.6.1.4.1.2021.11.54.0",
  "ssCpuRawKernel"=> ".1.3.6.1.4.1.2021.11.55.0",
  "ssCpuRawInterrupt"=> ".1.3.6.1.4.1.2021.11.56.0",
  "ssCpuRawSoftIRQ"=> ".1.3.6.1.4.1.2021.11.61.0",
  "ssCpuIdle"=> ".1.3.6.1.4.1.2021.11.11.0"
}

begin
  eth_oids = get_ethernet_oids(host)
rescue
  eth_oids = {}
end
oids.merge!(eth_oids)

oids.each do |name,oid|
  bundle['config']["oid_#{name}"] = oid
  bundle['metrics'] << {
    'type' => 'numeric',
    'name' => name
  }
end

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


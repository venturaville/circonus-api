#!/usr/bin/env ruby
# Add a single nginx host to circonus

require 'circonusutil'

host = nil
cu = CirconusUtil.new() { |opts,options|
  options[:broker] = nil
  options[:tags] = ['application:nginx']
  opts.banner = "Usage: #{File.basename($0)} hostname\n"
  opts.on( '--tags TAGLIST',"Apply comma separated list of tags (default: empty list)" ) { |t| options[:tags] += options[:tags] + t.split(/,/) }
  opts.on( '--broker BROKER',"Name of the broker to use" ) { |t| options[:broker] = t }
}
if ARGV.empty? then
  puts "Missing hostname!"
  exit -1
end
host = ARGV.pop

def do_update_check_bundle(cu,data)
  search_check_bundle = cu.circonus.list_check_bundle({'display_name' => data['display_name']})
  existing = false
  if search_check_bundle.any? # already exists...
    existing = true
    r = cu.circonus.update_check_bundle(search_check_bundle.first['_cid'],data)
  else
    r = cu.circonus.add_check_bundle(data)
  end
  if not r.nil? then
    pp r
    print "Success (#{existing ? 'updating' : 'adding'} #{data['display_name']})\n"
  end
end

agents = cu.circonus.list_broker({'_name'=>cu.options[:broker]})
agentid = agents.select { |a| a['_name'] == cu.options[:broker] }.first['_cid']
if agentid.nil?
  puts "Missing agent id!"
  exit -1
end

print "Adding nginx for host #{host}\n"
data = {
  :agent_id => agentid,
  :target => host,
  :module => "nginx",
}
bundle = {
  "type" => "nginx",
  "target" => host,
  "tags" => cu.options[:tags],
  "timeout" => 10,
  "period" => 60,
  "display_name" => "#{host} nginx",
  "brokers" => [
    agentid
  ],
  "metrics" => [
  ],
  "config" => {
    "url" => "http://#{host}/server-status"
  }
}
%w{ handled waiting requests accepted active duration reading writing }.each do |metric|
  bundle['metrics'] << {
    'type' => 'numeric',
    'name' => metric
  }
end

do_update_check_bundle(cu,bundle)


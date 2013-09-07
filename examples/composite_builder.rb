#!/usr/bin/env ruby

# Create composites for all unique metric names on a set of check bundles
# matching an intersection of a set of tags and a check bundle type

# This creates a total (named the same as: metricname)
# and an average (which is named as: metricname_avg)

require 'rubygems'
require 'circonus'
require 'optparse'
require "#{ENV['HOME']}/.circonus.rb"


def do_update_check_bundle(data)
  search_check_bundle = @cached_list_check_bundle.select { |s| s['display_name'] == data['display_name'] }
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
  opts.banner = "Usage: #{File.basename($0)} [-h] [-t tag1,tag2,...]\n"
  opts.on( '-h', '--help', "This usage menu") do
    puts opts
    exit
  end
  opts.on( '--type TYPE',"Check bundle type" ) do |t|
    options[:type] = t
  end
  opts.on( '-t','--tags TAGLIST',"Use comma separated list of tags for searching (takes the union)" ) do |t|
    options[:tags] += t.split(/,/).sort.uniq
  end
}.parse!

def usage()
  print <<EOF
  Usage: #{File.basename($0)} -t tag1,tag2,... --type CHECKBUNDLETYPE
    -h,--help        This usage menu
    -t,--tags        Comma separated list of tag names to use
    --type           check bundle type (snmp, nginx, etc.)
EOF
end

raise "No tags given" unless options[:tags].any?
raise "No type given" unless options[:type]
@c = Circonus.new(@apitoken,@appname,@agent)

# the agent that will do composites for us:
agentid = @c.list_broker({'_name'=>'composite'}).first['_cid']

# Get a cached copy for later use (this part is slow)
@cached_list_check_bundle = @c.list_check_bundle

# checkbundles matching what we want:
checkbundles = @cached_list_check_bundle.select { |s| ((s['tags'].sort.uniq & options[:tags]) == options[:tags]) and (s['type'] == options[:type]) }

# unique metric names:
metrics = checkbundles.map { |m| m['metrics'].map { |mn| mn['name'] } }.flatten.sort.uniq

# checkids in the group:
checkids = checkbundles.map { |m| m['_checks'] }.flatten

puts metrics.inspect
metrics.each do |metric|
  formula = '(' + checkids.map { |cid| "metric:counter(#{cid.split('/').last}, \"#{metric}\", 60000)" }.join(" + ") + ')'
  bundle = {
    "brokers"=>[agentid],
    "config"=>{
      "formula"=>formula,
      "composite_metric_name"=>metric
    },
    "display_name"=>"Composite Sum: #{options[:tags].join(',')} - #{metric}",
    "metrics"=>[
      {"name"=>metric, "status"=>"active", "type"=>"numeric"}
    ],
    "notes"=>nil,
    "period"=>60,
    "status"=>"active",
    "tags"=>options[:tags],
    "target"=>"ouzo.edge",
    "timeout"=>10,
    "type"=>"composite"
  }

  # Create total of metrics
  do_update_check_bundle(bundle)

  # Get average of metrics
  bundle['config']['formula'] = "#{formula} / #{checkids.length}"
  bundle['config']['composite_metric_name'] = "#{metric}_avg"
  bundle['display_name']="Composite Avg: #{options[:tags].join(',')} - #{metric}"
  bundle['metrics'].first['name'] = "#{metric}_avg"
  do_update_check_bundle(bundle)
end


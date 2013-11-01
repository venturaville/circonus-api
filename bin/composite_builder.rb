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
    #pp search_check_bundle.first['_cid']
    #pp data
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
options[:datatype] = 'counter'
options[:consolidation] = 'sum'
OptionParser.new { |opts|
  opts.banner = "Usage: #{File.basename($0)} [-h] [-t tag1,tag2,...]\n"
  opts.on( '-h', '--help', "This usage menu") do
    puts opts
    exit
  end
  opts.on( '--counter',"Counter" ) do
    options[:datatype] = 'counter'
  end
  opts.on( '--gauge',"Gauge" ) do
    options[:datatype] = 'average'
  end
  opts.on( '--average',"Average" ) do
    options[:consolidation] = 'average'
  end
  opts.on( '--sum',"Sum" ) do
    options[:consolidation] = 'sum'
  end
  opts.on( '--type TYPE',"Check bundle type" ) do |t|
    options[:type] = t
  end
  opts.on( '--metric METRICNAME',"Metric name" ) do |m|
    options[:metric] = m
  end
  opts.on( '-t','--tags TAGLIST',"Use comma separated list of tags for searching (takes the union)" ) do |t|
    options[:tags] += t.split(/,/).sort.uniq
  end
}.parse!

def usage()
  print <<EOF
  Usage: #{File.basename($0)} -t tag1,tag2,... --type CHECKBUNDLETYPE
    -h,--help             This usage menu
    -t,--tags             Comma separated list of tag names to use
    -m,--metric METRIC    Metric name
    --counter             Set if the metric is a counter (default)
    --gauge               Set if the metric is a gauge
    --sum                 Set if you want a sum (default)
    --average             Set if you want an average
    --type                check bundle type (snmp, nginx, etc.)
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
if options[:metric]
  if not metrics.include? options[:metric]
    raise "No matching metric name (#{options[:metric]}) found in check bundle"
  else
    metrics = [options[:metric]]
  end
end

# checkids in the group:
checkids = checkbundles.map { |m| m['_checks'] }.flatten

puts metrics.inspect
metrics.each do |metric|
  formula = '(' + checkids.map { |cid| "metric:#{options[:datatype]}(#{cid.split('/').last}, \"#{metric}\", 60000)" }.join(" + ") + ')'
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
    "target"=>"composite",
    "timeout"=>10,
    "type"=>"composite"
  }

  if options[:consolidation] == 'sum'
    # Create total of metrics
    do_update_check_bundle(bundle)
  end

  # Get average of metrics
  bundle['config']['formula'] = "#{formula} / #{checkids.length}"
  bundle['config']['composite_metric_name'] = "#{metric}_avg"
  bundle['display_name']="Composite Avg: #{options[:tags].join(',')} - #{metric}"
  bundle['metrics'].first['name'] = "#{metric}_avg"
  if options[:consolidation] == 'average'
    do_update_check_bundle(bundle)
  end
end


#!/usr/bin/env ruby
#
# Add alerts for nginx based service
#
# -- David Nicklay
#

require 'rubygems'
require 'circonus'
require "#{ENV['HOME']}/.circonus.rb"
@c = Circonus.new(@apitoken,@appname,@agent)

if ((ARGV.length < 1) or ARGV[0].match('^-')) then
  print "Usage: add_nginx_alerts.rb template_name [alertid]\n"
  exit(-1)
end
template_name = ARGV[0]
alertid = ARGV[1]

agents = @c.list_broker
agentid = agents.select { |a| a['_name'] == @agent }.first['_cid']

datapoints = 'requests'

title = "#{template_name} - #{datapoint}"
data = {
  "title"=>"nginx #{title}",
  "style"=>"area",
  "max_right_y"=>nil,
  "min_right_y"=>nil,
  "min_left_y"=>nil,
  "max_left_y"=>nil,
  "guides"=>[],
  "datapoints"=> [],
  "composites"=> []
}

dpstub = {
  "axis"=>"l",
  "stack"=>nil,
  "metric_type"=>"numeric",
  "data_formula"=>nil,
  "name"=>nil,
  "derive"=>"counter",
  "metric_name"=>nil,
  "color"=>"#33aa33",
  "check_id"=>nil,
  "legend_formula"=>nil,
  "hidden"=>false
}

# No SUM(*) is available, so we have to generate a formula ourselves:
# Generate a total formula =A+B+C...... using the number of datapoints
def get_total_formula(npoints)
  i = 0
  formula = "="
  a = 'A'..'ZZZZ'
  a.each do |x|
    i += 1
    formula += x
    break if i == npoints
    formula += "+"
  end
  return formula
end

# get unique values from an array of hashes given an index to compare on
def get_unique(array,index)
  a = array.sort_by { |x| x[index] }
  return a.inject([]) do |result,item| 
    result << item if !result.last||result.last[index]!=item[index]
    result
  end
end

# Get list of hosts on template
hosts = @c.list_template.select { |t| t['name'] == template_name }.first['hosts']
# Get list of check ids to use:
bundles = @c.list_check_bundle().select { |b| hosts.include? b['target'] }
checkids = get_unique(bundles,'target').map { |j| j['_checks'].first }
checkids.each do |checkid|
  cid = checkid.to_a.first.gsub(/^.*\//,'')
  %w{ requests }.each do |metric|
    dp = dpstub.clone
    dp['name'] = "nginx #{title} - #{metric}"
    dp['metric_name'] = metric
    if %w{ accepted handled requests }.include? metric then
      dp['derive'] = "counter"
    end
    dp['color'] = nil

    dp['stack'] = 0
    dp['check_id'] = cid
    dp['hidden'] = true

    data['datapoints'] << dp
  end
end



# Do composite total:
formula = get_total_formula(data['datapoints'].length)
totaldp = {
  "name"=>"Total Reqs/s",
  "axis"=>"l",
  "stack"=>nil,
  "legend_formula"=>"=ceil(VAL)",
  "color"=>"#33aa33",
  "data_formula"=>formula,
  "hidden"=>false
}
data['composites'] << totaldp


guidepct = {
  "data_formula"=>"99%",
  "name"=>"99th Percentile",
  "color"=>"#ea3a92",
  "hidden"=>false,
  "legend_formula"=>"=ceil(VAL)"
}
data['guides'] << guidepct

exit
if graphid.nil? then
  r = @c.add_graph(data)
else
  r = @c.update_graph(graphid,data)
end
pp r


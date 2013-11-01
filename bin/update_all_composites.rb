#!/usr/bin/env ruby
#
# Use tags on existing composites to automate the updating of formulas on them
#

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

@c = Circonus.new(@apitoken,@appname,@agent)

# the agent that will do composites for us:
agentid = @c.list_broker({'_name'=>'composite'}).first['_cid']

# Get a cached copy for later use (this part is slow)
@cached_list_check_bundle = @c.list_check_bundle()

def get_tag_values(tags)
  Hash[tags.map { |e| e.split(':',2) }] # convert tag list to a hash (Note: this squashes duplicates)
end

# Generate the composite formula
def generate_formula(checkids,consolidation,datatype,metric)
  formula = '(' + checkids.map { |cid| "metric:#{datatype}(#{cid.split('/').last}, \"#{metric}\", 60000)" }.join(" + ") + ')'
  if consolidation == 'average'
    formula = "#{formula} / #{checkids.length}"
  end
  formula
end

# Test to see if the composite needs updating
def composite_update(composite,tags,select_tags)
  puts composite['display_name']

  # get list of check bundles given the set of tags and type
  cbs = @cached_list_check_bundle.select { |s| s['type'] == tags['type'] }
  select_tags.each do |tag|
    cbs = cbs.select { |s| s['tags'].include? tag }
  end
  checkids = cbs.map { |m| m['_checks'].first.split('/').last }.sort

  new_formula = generate_formula(checkids,tags['consolidation'],tags['datatype'],tags['metric'])
  if composite['config']['formula'] != new_formula
    puts "Needs updating!"
    # --TODO actually do the update
  end
    puts "old_formula: #{composite['config']['formula']}"
    puts "new_formula: #{new_formula}"
end

automation_tags = %w{ consolidation datatype type source metric }
composites = @cached_list_check_bundle.select { |s|
  s['tags'].include?('source:composite-builder') and (s['type'] == 'composite')
}
composites.each do |composite|
  select_tags = composite['tags'].select { |s| not (automation_tags.include? s.split(':').first) } # strip automation tags
  tags = get_tag_values(composite['tags'])
  next if tags['type'].nil? or tags['datatype'].nil? or tags['consolidation'].nil? or tags['metric'].nil?
  next if tags['type'].empty? or tags['datatype'].empty? or tags['consolidation'].empty? or tags['metric'].empty?

  composite_update(composite,tags,select_tags)
  #puts cbs.map { |m| m['display_name'] }

  # TODO: test for composite changes and update as needed

end

__END__
checkbundles = @cached_list_check_bundle.select { |s| ((s['tags'].sort.uniq & options[:tags]) == options[:tags]) and (s['type'] == options[:checkbundletype]) }

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
    "tags"=>(options[:tags] + options[:automation_tags] + ["metric:#{metric}"]),
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


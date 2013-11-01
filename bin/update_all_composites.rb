#!/usr/bin/env ruby
#
# Use tags on existing composites to automate the updating of formulas on them
#

require 'rubygems'
require 'circonus'
require 'optparse'
require "#{ENV['HOME']}/.circonus.rb"

def do_update_check_bundle(data)
  r = @c.update_check_bundle(data['_cid'],data)
  if not r.nil? then
    pp r
    print "Success updating #{data['display_name']})\n"
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
    composite['config']['formula'] = new_formula
    composite['config']['composite_metric_name'] = tags['metric']
    do_update_check_bundle(composite)
  end
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
end


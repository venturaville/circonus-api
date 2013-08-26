#!/usr/bin/env ruby

require 'rubygems'
require 'circonus'
require 'optparse'
require 'pp'
require "#{ENV['HOME']}/.circonus.rb"

class CirconusUtility
  attr_accessor :c, :args, :debug_flag, :template, :tags

  def initialize(apitoken,appname)
    @args = []
    @c = Circonus.new(apitoken,appname,nil)
    @debug_flag = true
    @template = nil
    @tags = []
    options()
  end
  def debug(msg)
    puts msg if @debug_flag
  end
  def options
    options = {}
    options[:tags] = []
    OptionParser.new { |opts|
      opts.banner = "Usage: #{File.basename($0)} [-h] argument [-t tag1,tag2,...]\n"
      opts.on( '-h', '--help', "This usage menu") do
        puts opts
        exit
      end
      opts.on( '-t','--tags TAGLIST',"Apply comma separated list of tags" ) do |t|
        options[:tags] += t.split(/,/)
      end
    }.parse!
    @tags = options[:tags]
    @args = ARGV
    usage(-1) unless @args.any?
  end
  def usage(exitcode=nil)
    print <<EOF
    Usage: #{File.basename($0)} argument [-t tag1,tag2,... ]
      -h,--help        This usage menu
      -t,--tags        Comma separated list of tag names to apply (default is an empty list)
EOF
    exit(exitcode) unless exitcode.nil?
  end

  def do_update_check_bundle
    search_check_bundle = @c.list_check_bundle({'display_name' => @template['display_name']})
    existing = false
    if search_check_bundle.any? # already exists...
      existing = true
      r = @c.update_check_bundle(search_check_bundle.first['_cid'],@template)
    else
      r = @c.add_check_bundle(@template)
    end
    if not r.nil? then
      #debug "Result: #{r.inspect}"
      debug "Success (#{existing ? 'updating' : 'adding'} #{@template['display_name']})\n"
    end
  end

  def update
    do_update_check_bundle
  end

end

def get_nameservers(target)
  list = `dig +short -t ns #{target} @8.8.8.8` # use Google public dns to look it up
  nameservers = list.split().map { |m| m.sub(/\.$/,'') }
  unless $?.to_i == 0
    puts "nameservers lookup failed: #{list}"
    exit($?.to_i)
  end
  return nameservers
end

cu = CirconusUtility.new(@apitoken,@appname)
template = {
  "brokers"=>["/broker/1"],
  "config"=>{ "ctype"=>"IN", "query"=>"www.hostname.com", "rtype"=>"NS" },
  "display_name"=>"DNS - www.hostname.com @mydns.dns.com",
  "metrics"=>
  [
    {"name"=>"answer", "status"=>"active", "type"=>"text"},
    {"name"=>"cname", "status"=>"active", "type"=>"numeric"},
    {"name"=>"rtt", "status"=>"active", "type"=>"histogram"}
  ],
  "notes"=>nil,
  "period"=>60,
  "status"=>"active",
  "tags"=>[],
  "target"=>"mydns.dns.com",
  "timeout"=>10,
  "type"=>"dns"
}

cu.debug_flag = true
hostnames = cu.args
hostnames.each do |hostname|
  nameservers = get_nameservers(hostname)
  cu.debug "Updating nameserver monitors for hostname: #{hostname} nameservers: #{nameservers.join(',')}"
  nameservers.each do |ns|
    template['display_name'] = "DNS - #{hostname} @#{ns}"
    template['target'] = ns
    template['config']['query'] = hostname
    template['tags'] = cu.tags
    cu.template = template
    #cu.debug "Template=#{template.inspect}"
    cu.update
  end
end


require 'rubygems'
require 'circonus'
require 'optparse'
class CirconusUtil
  attr_accessor :options
  attr_accessor :circonus
  def parse_opts()
    OptionParser.new { |opts|
      opts.banner = "Usage: #{File.basename($0)}\n"
      opts.on( '-h', '--help', "This usage menu") do
        puts opts
        exit
      end
      opts.on( '-a','--appname APPNAME',"Name of application to report to Circonus (default: curl)" ) do |t|
        @options[:appname] = t
      end
      opts.on( '-s','--server APISERVER',"API server to use (default: api.circonus.com)" ) do |t|
        @options[:apiserver] = t
      end
      opts.on( '-t','--token APITOKEN',"API token to use (required)" ) do |t|
        @options[:apitoken] = t
      end
      unless @additional_opts.nil?
        @additional_opts.call(opts,@options)
      end
    }.parse!
    if options[:apitoken].to_s.empty?
      puts "Missing apitoken!"
      exit -1
    end
  end
  def connect
    @circonus = Circonus.new(@options[:apitoken],@options[:appname])
    @circonus.set_server(@options[:apiserver])
  end
  def initialize(&addl_opts)
    @options = {}
    @options[:apiserver] = ENV['CIRCONUS_APISERVER'] || "api.circonus.com" # can be something else for Circonus inside product...
    @options[:appname] = ENV['CIRCONUS_APPNAME'] || "curl"
    @options[:apitoken] = ENV['CIRCONUS_APITOKEN']
    @additional_opts = addl_opts
    self.parse_opts
    self.connect
  end
end

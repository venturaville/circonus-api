#!/usr/bin/env ruby
# Make a cached copy of all of what is in circonus API

require 'rubygems'
require 'circonus'
require 'json'
require "#{ENV['HOME']}/.circonus.rb"
@c = Circonus.new(@apitoken,@appname,@agent)

@c.methods.select { |m| m.match('^list_') }.each do |m|
  begin
    data = @c.send m.to_sym
    type = m.sub('list_','')
    Dir.mkdir 'cache' unless File.directory?('cache')
    f = File.open File.join('cache',"#{type}.json"), "w"
    f.write JSON.pretty_generate(data)
    f.close
  rescue RestClient::ResourceNotFound => e
  end
end


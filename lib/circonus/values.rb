#!/usr/bin/env ruby
# Query Circonus data (used by the Circonus UI's javascript)
# Notes:
# - This is not the permanent API for this....
#
# Tue Oct  9 11:11:01 EDT 2012
# -- David Nicklay

require 'rubygems'
require 'net/http' # necessarily evil ... rest-client won't return set-cookie values on 302s....
require 'net/https'
require 'pp'
require 'cgi'
require 'yajl'


class Circonus
  class Values
    attr_accessor :raise_errors
    attr_accessor :debug

    def initialize(username,password,account='')
      @username = username
      @password = password
      @cookie = ''
      @debug = true
      @host = 'circonus.com'
      @login_host = "login.circonus.com"
      @account = account
      @data_host = "#{@account}.circonus.com"
      @raise_errors = false
      @data_prefix = "/json/graph/data/"
      @metrics_prefix = "/account/#{@account}/json/metrics/value"

      @headers = {
        "X-Circonus-Auth-Token" => @apitoken,
        "X-Circonus-App-Name" => @appname,
        "Accept" => 'application/json'
      }
      @url_v1_prefix = "https://circonus.com/api/json/"
      @url_prefix = "https://api.circonus.com/v2/"
    end

    # You need to call login before doing anything ... This gives us our session id
    def login()
      http = Net::HTTP.new(@login_host, 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      path = '/login'
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
      data="login_username=#{CGI.escape @username}&login_password=#{CGI.escape @password}&login_remember=1&whereTo=https://#{@account}.circonus.com%2Flogin&&login_submit=Sign+In+%BB&welcome_submit=Sign+In+%BB"

      resp = http.post(path, data, headers)
      @cookie = resp.response['set-cookie'].split('; ')[0]
      return true
    end

    # Get the value of a particular metric name
    def metric_value(checkid,metric_name)
      http = Net::HTTP.new(@data_host, 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      path = "#{@metrics_prefix}?check_id=#{CGI.escape checkid.to_s}&metric_name=#{CGI.escape metric_name}"
      headers = {
        'Cookie' => @cookie,
        'Accept' => 'application/application/json, text/javascript, */*; q=0.01'
      }
      resp = http.get(path, headers)
      return Yajl::Parser.parse(resp.body)
    end

    # Get the range of data values from start to end time (t_start and t_end should be Time class vars)
    def graph_data(uuid,t_start=nil,t_end=nil)
      http = Net::HTTP.new(@data_host, 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      # set sane defaults
      t_end = Time.new if t_end.nil?
      t_start = (t_end - 300) if t_start.nil?
      # convert to strings
      s_t_mid = (t_start + ((t_end - t_start) / 2)).strftime('%s')
      s_t_start = t_start.strftime('%s')
      s_t_end = t_end.strftime('%s')
      uuid = uuid.split('/').last # make sure we don't have /graph in the id....
      path = "#{@data_prefix}#{uuid}?start=#{s_t_start}000&end=#{s_t_end}000cnt=&type=&times=epoch_ms&_=#{s_t_mid}000"
      headers = {
        'Cookie' => @cookie,
        'Accept' => 'application/application/json, text/javascript, */*; q=0.01'
      }
      resp = http.get(path, headers)
      return Yajl::Parser.parse(resp.body)
    end

    # Convenience function ... get the last graph data points
    # (We use 300 seconds to make sure we at least have something....)
    def last_graph_data(uuid)
      t = Time.new
      return graph_data(uuid,t - 300, t)
    end

    # Find the first valid data point in our set
    def _first_valid_datapoint(data)
      return nil if data.nil? or not data.any?
      begin
        data.reverse.select { |s| not s[1].nil? }.first[1]
      rescue Exception => e
        return nil
      end
    end

    # Get the sum of the last valid graph point
    def total_last_graph_data(uuid)
      data = last_graph_data(uuid)
      sum = 0
      data['data'].each do |d|
        next unless d['metric_type'] == 'numeric'
        sum += _first_valid_datapoint(d['data']).to_f
      end
      return sum
    end

    def eval_formula(formula,values=[])
      formula = formula.clone
      formula.tr!('^A-Za-z0-9/+.*_)(-','' ) # prevent injection
      formula.tr!('A-Z','a-z')
      formula.gsub!(/[a-z]+/) { |n| "var_#{n}" } # prevent clobbering of ruby keywords
      evalstr = ""
      ('a'..'zzzz').each_with_index do |x,i|
        break if i == values.length
        evalstr += "var_#{x}=#{values[i].to_f.to_s}\n" # force an s->i->s conversion to prevent injection in the values
      end
      results = eval "#{evalstr}\n#{formula}\n"
    end

    def eval_composite(composite,values)
      return eval_formula(composite['reconnoiter_source_expression'],values)
    end

    def eval_composites(uuid)
      data = last_graph_data(uuid)
      values = []
      composites = []
      data['data'].each do |d|
        if d['metric_type'] == 'numeric'
          values << _first_valid_datapoint(d['data']).to_f
        elsif d['metric_type'] == 'composite'
          composites << d
        end
      end
      composites.each do |composite|
        composite['result'] = eval_composite(composite,values)
      end
      return composites
    end

  end
end


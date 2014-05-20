#!/usr/bin/env ruby
# Tue Sep 18 20:18:09 EDT 2012
# -- David Nicklay
#https://circonus.com/resources/api/templates

require 'rubygems'
require 'restclient'
require 'uri'
require 'pp'
require 'yajl'

class Circonus
  attr_accessor :agent
  attr_accessor :raise_errors
  attr_accessor :debug

  class Timeout < RestClient::RequestTimeout
  end

  DEFAULT_OPTIONS = {
    :timeout => 300,
    :open_timeout => 300
  }

  def set_apitoken(apitoken)
    @apitoken = apitoken
  end

  def set_appname(appname)
    @appname = appname
  end

  def set_server(server)
    @url_prefix = "https://#{server}/v2/"
  end
  
  def initialize(apitoken,appname,agent=nil, options={})
    @apitoken = apitoken
    @debug = true
    @raise_errors = false
    @appname = appname
    @agent = agent
    @headers = {
      "X-Circonus-Auth-Token" => @apitoken,
      "X-Circonus-App-Name" => @appname,
      "Accept" => 'application/json'
    }
    @url_prefix = "https://api.circonus.com/v2/"
    @options = DEFAULT_OPTIONS.merge(options)
  end

  def _rest(type,url,headers,data=nil)
    #STDERR.puts "_rest: type=#{type} url=#{url} headers=#{headers.inspect} data=#{data.inspect}"
    begin
      resource = RestClient::Resource.new url, :timeout => @options[:timeout], :open_timeout => @options[:open_timeout]
      case type
      when 'delete'
        r = resource.delete headers
      when 'post'
        r = resource.post Yajl::Encoder.encode(data), headers
      when 'put'
        r = resource.put Yajl::Encoder.encode(data), headers
      else 'get'
        r = resource.get headers
      end
    rescue RestClient::Forbidden,RestClient::BadRequest,RestClient::InternalServerError,RestClient::MethodNotAllowed => e
      err = Yajl::Parser.parse(e.response)
      print "Error (#{e.http_code}): ",err['error']," [#{e.http_body}]\n" if @debug
      raise if @raise_errors
      return nil,err
    rescue RestClient::RequestTimeout
      raise Circonus::Timeout
    end
    return r
  end

  def get(method,id)
    cid = id.to_s.split('/').last
    url = @url_prefix + method + '/' + URI.escape(cid)
    #print "url=#{url}\n"
    r,err = _rest('get',url, @headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def delete(method,id)
    cid = id.to_s.split('/').last
    url = @url_prefix + method + '/' + URI.escape(cid)
    r,err = _rest('delete',url, @headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def add(method,data)
    r, err = _rest('post',@url_prefix + method, @headers, data)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def update(method,id,data)
    cid = id.to_s.split('/').last
    r, err = _rest('put',@url_prefix + method + '/' + URI.escape(cid), @headers, data)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def list(method,filter=nil)
    url = @url_prefix + method
    if (not filter.nil?) and filter.any?
      query_string = filter.map { |k,v| [v].flatten.map { |val|"f_#{URI::escape(k)}=#{URI::escape(val)}" } }.flatten.join('&')
      url += '?' + query_string
    end
    r, err = _rest('get',url,@headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  # Not all these are available:
  %w{ account annotation broker check_bundle contact_group graph metric_cluster rule_set template user worksheet check }.each do |m|
    define_method("list_#{m}".to_sym) do |*filter|
      return list(m,filter.first)
    end
    define_method("get_#{m}".to_sym) do |id|
      return get(m,id)
    end
    define_method("delete_#{m}".to_sym) do |id|
      return delete(m,id)
    end
    define_method("add_#{m}".to_sym) do |data|
      return add(m,data)
    end
    define_method("update_#{m}".to_sym) do |id,data|
      return update(m,id,data)
    end
    define_method ("search_#{m}".to_sym) do |match,field|
      return list(m).select { |t| t[field].match(match) }
    end
  end

  %w{ alert }.each do |m|
    define_method("list_#{m}".to_sym) do |*filter|
      return list(m,filter.first)
    end
    define_method("get_#{m}".to_sym) do |id|
      return get(m,id)
    end
  end

  # extraction of time ranged data (this one is a bit different from the other v2 ones)
  def get_data(cid,metric,params = {})
    params['start'] = (Time.now - 3600).to_i unless params.has_key? 'start'
    params['end'] = Time.now.to_i unless params.has_key? 'end'
    params['period'] = 300 unless params.has_key? 'period'
    params['type'] = 'numeric' unless params.has_key? 'type'
    url = @url_prefix + 'data' + '/' + URI.escape(cid.to_s.split('/').last) + '_' + URI::escape(metric)
    headers = @headers.merge({:params => params})
    r,err = _rest('get',url, headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def _data_formula(formula,data)
    vals = []
    formula = formula.clone
    formula.tr!('^A-Za-z0-9/+.*_)(-','' ) # prevent injection
    formula.tr!('A-Z','a-z')
    formula.gsub!(/[a-z]+/) { |n| "var_#{n}" } # prevent clobbering of ruby keywords
    data.each_with_index do |v,i|
      res = eval "var_val=#{v[1]}\n#{formula}\n"
      vals[i] = [v[0],res]
    end
    return vals
  end

  def _data_derive(data,datapoint)
    derive = datapoint['derive']
    derive = 'value' if derive == 'gauge'
    data = data.map { |m| [m[0],(m[1] ? m[1][derive] : nil)] }
    data = _data_formula(datapoint['data_formula'],data) if datapoint['data_formula']
    return data
  end

  def _composite_formula(formula,graph)
    formula = formula.clone
    formula.tr!('^A-Za-z0-9/+.*_)(-','' ) # prevent injection
    formula.tr!('A-Z','a-z')
    formula.gsub!(/[a-z]+/) { |n| "var_#{n}" } # prevent clobbering of ruby keywords
    dps = graph['datapoints']
    ndps = dps.length
    nvals = dps.first['data'].length
    data = []
    (0...nvals).each do |n|
      evalstr = ""
      ('a'..'zzzz').each_with_index do |x,i|
        break if i == ndps
        evalstr += "var_#{x}=#{dps[i]['data'][n].last.to_f.to_s}\n" # force an s->i->s conversion to prevent injection in the values
      end
      res = eval "#{evalstr}\n#{formula}\n"
      data[n] = [dps.first['data'][n].first,res]
    end
    return data
  end

  # Get the range of data values from start to end time
  # This calculates out the datapoints and composites using the formulas in each graph
  # --TODO This is very slow at the moment.......
  def get_graph_data(gid,t_start=nil,t_end=nil)
    t_end ||= Time.new.to_i
    t_start ||= (t_end - 600)
    g = get_graph(gid)
    params = {'end'=>t_end.to_i,'start'=>t_start.to_i}
    g['datapoints'].each do |dp|
      res = get_data(dp['check_id'],dp['metric_name'],params)
      data = res['data']
      dp['data'] = _data_derive(data,dp)
    end
    g['composites'].each do |cmp|
      cmp['data'] = _composite_formula(cmp['data_formula'],g)
    end
    return g
  end
end


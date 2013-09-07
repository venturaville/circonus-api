#!/usr/bin/env ruby
# Tue Sep 18 20:18:09 EDT 2012
# -- David Nicklay
#https://circonus.com/resources/api/templates
# --TODO caught in between v1 and v2 docs at the moment ... class is a mess because of it

require 'rubygems'
require 'restclient'
require 'cgi'
require 'pp'
require 'yajl'

class Circonus
  attr_accessor :agent
  attr_accessor :raise_errors
  attr_accessor :debug

  class Timeout < RestClient::RequestTimeout
  end

  DEFAULT_OPTIONS = {
    :timeout => 20,
    :open_timeout => 20
  }
  
  def initialize(apitoken,appname,agent, options={})
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
    @url_v1_prefix = "https://circonus.com/api/json/"
    @url_prefix = "https://api.circonus.com/v2/"
    @options = DEFAULT_OPTIONS.merge(options)
  end

  def _rest(type,url,headers,data=nil)
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
    url = @url_prefix + method + '/' + cid
    #print "url=#{url}\n"
    r,err = _rest('get',url, @headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def delete(method,id)
    cid = id.to_s.split('/').last
    url = @url_prefix + method + '/' + cid
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
    r, err = _rest('put',@url_prefix + method + '/' + cid, @headers, data)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def list(method,filter=nil)
    url = @url_prefix + method
    if (not filter.nil?) and filter.any?
      query_string = filter.map { |k,v| "f_#{CGI::escape(k)}=#{CGI::escape(v)}" }.join('&')
      url += '?' + query_string
    end
    r, err = _rest('get',url,@headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def v1_list(method)
    url = @url_v1_prefix + 'list_' + method
    r, err = _rest('get',url,@headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def v1_get(method,id)
    cid = id.to_s.split('/').last
    headers = @headers.merge({:params => {"#{method}_id".to_sym => cid}}) # attempt to guess at the id name expected
    url = @url_v1_prefix + 'get_' + method
    #print "url=#{url}\n"
    #pp headers
    r, err = _rest('get',url, headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def v1_delete(method,id)
    cid = id.to_s.split('/').last
    headers = @headers.merge({:params => {"#{method}_id".to_sym => cid}}) # attempt to guess at the id name expected
    url = @url_v1_prefix + 'delete_' + method
    r, err = _rest('delete',url, headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  def v1_add(method, data, params)
    headers = @headers.merge({:params => params})
    r,err = _rest 'get',@url_v1_prefix + 'add_' + method, headers, data
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  # Version 2
  # Not all these are available:
  %w{ account annotation broker check_bundle contact_group graph rule_set template user worksheet check }.each do |m|
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

  # extraction of time ranged data (this one is a bit different from the other v2 ones)
  def get_data(cid,metric,params = {})
    params['start'] = (Time.now - 3600).to_i unless params.has_key? 'start'
    params['end'] = Time.now.to_i unless params.has_key? 'end'
    params['period'] = 300 unless params.has_key? 'period'
    params['type'] = 'numeric' unless params.has_key? 'type'
    url = @url_prefix + 'data' + '/' + cid + '_' + CGI::escape(metric)
    #puts "url=#{url}" if @debug
    headers = @headers.merge({:params => params})
    r,err = _rest('get',url, headers)
    return nil,err if r.nil?
    return Yajl::Parser.parse(r)
  end

  # Version 1 (Deprecated)
  %w{ metric check template annotation graph worksheet rule account user agent }.each do |m|
    define_method("v1_list_#{m}s".to_sym) do
      return v1_list(m + 's')
    end
    define_method("v1_get_#{m}".to_sym) do |id|
      return v1_get(m,id)
    end
    define_method("v1_delete_#{m}".to_sym) do |id|
      return v1_delete(m,id)
    end
    define_method("v1_add_#{m}".to_sym) do |data,params|
      return v1_add(m,data,params)
    end
    define_method ("v1_search_#{m}".to_sym) do |match,field|
      return v1_list(m + 's').select { |t| t[field].match(match) }
    end
  end
end

require 'rubygems'
require 'oauth'
require "json"

require 'stack_mob_config'

class StackMobOauth
  def initialize(config, debug = false)
    @appname = config.appname
    
    @consumer = OAuth::Consumer.new(config.key, config.secret, {
        :site=>"http://meexo.stackmob.com"
        })

    @consumer.http.set_debug_output($stderr) if debug

    @access_token = OAuth::AccessToken.new @consumer
  end
  
  def model_path(method, model, opts)
    model_id = opts[:model_id]
    path = "/api/0/#{@appname}/#{model}"
    
    if method == :get || method == :delete
      if model_id && model_id != :all
        id_param = opts[:id_name].nil? ? "#{model}_id" : opts[:id_name]
        path = path + "?#{id_param}=#{model_id}"
      elsif opts[:json]
        params = JSON.parse(opts[:json])
        url_params = URI.escape(params.collect{|k,v| "#{k}=#{v}"}.join('&'))
        path = path + "?" + url_params
      end
    end
    path
  end

  def request(method, model, opts={})
    model_path = model_path(method, model, opts)
    
    headers = {}
    headers['Content-type' => 'application/json'] if opts[:json]
    
    response = case method
    when :get
      @access_token.get(model_path, headers)
    when :delete
      @access_token.delete(model_path, headers)
    when :create
      post_data = opts[:json]
      @access_token.post(model_path, post_data, headers)
    end
    
    if response.is_a? Net::HTTPOK
      return (response.body && response.body.length>0) ? JSON.parse(response.body) : nil
    end

    # handle error
    if (response.body && response.body.length>0)
      error_hash = {}
      begin
        error_hash = JSON.parse(response.body)
      rescue
        error_hash["response_error"] = "Bad response: #{response.body}"
      end
    else
      error_hash = {"response_error", "Bad empty response: #{response}"}
    end
    return error_hash
  end
      
  def get(model_or_action, opts = {})
    request(:get, model_or_action, opts)
  end

  def post(model, opts = {})
    request(:create, model, opts)
  end

  def delete(model, opts = {})
    request(:delete, model, opts)
  end
end

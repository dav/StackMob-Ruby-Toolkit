require 'rubygems'
require 'oauth'
require "json"

require 'stack_mob_config'

class StackMobOauth
  def initialize(config)
    @appname = config.appname
    
    @consumer = OAuth::Consumer.new(config.key, config.secret, {
        :site=>"http://meexo.stackmob.com"
        })

    # For debugging the http request
    #@consumer.http.set_debug_output($stderr)

    @access_token = OAuth::AccessToken.new @consumer
  end
  
  def model_path(model, model_id=nil)
    path = "/api/1/#{@appname}/#{model}"
    if model_id && model_id != :all
      path = path + "?#{model}_id=#{model_id}"
    end
    path
  end

  def request(method, model, opts={})
    model_path = model_path(model, opts[:model_id])
    if opts[:json]
      response = @access_token.send(method, model_path, opts[:json],{'Content-type'=>'application/json'})
    else
      response = @access_token.send(method, model_path)
    end
    if response.is_a? Net::HTTPOK
      if (response.body && response.body.length>0)
        return JSON.parse(response.body)
      else
        return nil
      end
    else
      if (response.body && response.body.length>0)
        error_hash = {}
        begin
          error_hash = JSON.parse(response.body)
        rescue
          error_hash["error"] = "Bad response: #{response.body}"
        end
      else
        error_hash = {"error", "Bad empty response: #{response}"}
      end
      return error_hash
    end
  end
      
  def get(model_or_action, model_id=nil)
    request(:get, model_or_action, :model_id => model_id)
  end

  def post(model_or_action, instance_json)
    request(:post, model_or_action, :json => instance_json)
  end

  def delete(model, model_id)
    request(:delete, model, :model_id => model_id)
  end
end

require 'rubygems'
require 'oauth'
require "json"

class StackMobOauth
  def initialize(config)
    @appname = config["default"]
    key = config[@appname]["key"]
    secret = config[@appname]["secret"]
    
    @consumer = OAuth::Consumer.new(key,secret, {
        :site=>"http://meexo.stackmob.com"
        })

    # For debugging the http request
    #@consumer.http.set_debug_output($stderr)

    @access_token = OAuth::AccessToken.new @consumer
  end
  
  def model_path(model, model_id=nil)
    path = "/api/1/#{@appname}/#{model}"
    unless model_id == :all
      path = path + "?#{model}_id=#{model_id}"
    end
    path
  end

  def request(method, model, model_id)
    model_path = model_path(model, model_id)
    response = @access_token.send(method, model_path)
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
      
  def get(model_or_action, model_id)
    request(:get, model_or_action, model_id)
  end

  def delete(model, model_id)
    request(:delete, model, model_id)
  end
end

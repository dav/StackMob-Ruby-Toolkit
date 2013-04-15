require 'rubygems'
require 'oauth'
require "json"
require 'uri'

require 'stack_mob/config'

module StackMob
  class Oauth
    def initialize(config, deployment, version, debug = false)
      @appname = config["application"]
      @version = version
      @debug = debug
      
      if debug
        puts "Using #{deployment} keys."
      end
      
      @consumer = OAuth::Consumer.new(config[deployment]["key"], config[deployment]["secret"], {
          #:site => "https://#{config["account"]}.stackmob.com"
          :site => "https://api.stackmob.com"
          })

      @consumer.http.set_debug_output($stderr) if debug
      #@consumer.http.read_timeout = 90   note apparently resetting the timeout to >90 here has no effect

      @access_token = OAuth::AccessToken.new @consumer
      #puts @consumer.http.instance_variable_get "@read_timeout"
    end

    def model_path(method, model, opts)
      model_id = opts[:model_id]
      #path = "/api/#{@version}/#{@appname}/#{model}"
      path = "/#{model}"

      if opts[:password] 
        # must be a login attempt (TODO ewwww)
        path += '/login' 
        id_param = opts[:id_name].nil? ? "#{model}_id" : opts[:id_name]
        path = path + "?#{id_param}=#{model_id}&password=#{opts[:password]}"
      elsif opts[:logout]
        path += '/logout'
      elsif method == :get || method == :delete
        if model_id && model_id != :all
          id_param = opts[:id_name].nil? ? "#{model}_id" : opts[:id_name]
          path = path + "?#{id_param}=#{model_id}"
        elsif opts[:json]
          params = JSON.parse(opts[:json])
          url_params = params.collect{|k,v| 
            value = opts[:custom_code_json] ? v : CGI.escape("#{v}")
            "#{k}=#{value}"
          }.join('&')
          path = path + "?" + url_params
        end
        
        if opts[:expand_depth]
          path += "&_expand=#{opts[:expand_depth]}"
        end
      end
      
      if qf_hash = opts[:query_filters]
        params = qf_hash.keys.map {|key| "#{key}=#{URI.escape((qf_hash[key]).to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}" }.join('&')
        path = path + '?' + params
      end
      
      path
    end

    def push_path
      "/push/0/#{@appname}/device_tokens"
    end

    def request(method, model, opts={})
      # TODO conceptually clean up this nuttiness before origin push. Ha! Too late!
      path = model == :push ? push_path : model_path(method, model, opts)

      headers = {}
      headers['Content-type'] = 'application/json' if opts[:json]
      
      cookie_file = (opts[:deployment] == 'production') ? "current_stackmob_production_login_cookie.txt" : "current_stackmob_sandbox_login_cookie.txt"
      
      if File.exists?(cookie_file)
        File.open(cookie_file, 'r') do |f|
          headers['Cookie'] = f.gets
        end
      end

      post_data = opts[:json]
      if @debug && post_data
        STDERR.puts "REQUEST DATA:\n#{post_data}"
      end

      if range = opts[:paginate]
        headers['Range'] = "objects=#{opts[:paginate]}"
      end
      
      headers["Accept"] = "application/vnd.stackmob+json; version=#{@version}"
      
      response = case method
      when :get
        @access_token.get(path, headers)
      when :delete
        @access_token.delete(path, headers)
      when :create
        @access_token.post(path, post_data, headers)
      when :put
        @access_token.put(path, post_data, headers)
      end

      response_range = response["Content-Range"]
      unless response_range.nil? || response_range == ''
        if response_range =~ /objects (\d+)-(\d+)\/\d+/
          range_start = $1
          range_end = $2
        end
        STDERR.puts "GOT #{model} #{response_range}"
      end
      
      if opts[:paginate]
        if opts[:paginate] =~ /^(\d+)-(\d+)$/
          paginate_start = $1
          paginate_end = $2
        end
        if response_range && response_range != 'objects *' &&  response_range != '' &&  (paginate_start != range_start || paginate_end != range_end)
          STDERR.puts "*** WARNING: Requested range #{opts[:paginate]} != response range '#{response_range}'"
        end
      end
      
      cookie = response["Set-Cookie"]
      unless cookie.nil?
        File.open(cookie_file,'w') do |f|
          f.write cookie
        end
      end

      if response.code =~ /^2/
        result = nil
        if response.body && response.body.length>0
          # StackMob apparently sometimes does not return JSON
          if response.body =~ /^Success/
            result = {"response" => response.body}
          else
            result = JSON.parse(response.body)
          end
        end
        
        if result.is_a?(Array) && range_start && range_end
          # verify range fulfilled
          expected_size = range_end.to_i - range_start.to_i + 1 # because the response is 0-499 for 500 items
          if result.size != expected_size
            STDERR.puts "*** WARNING: Result shuld be size=#{expected_size} but it is size=#{result.size}"
          end
        end
        return result
      end
      
      # if we got this far there is an error
      # handle error
      if (response.body && response.body.length>0)
        error_hash = {}
        begin
          error_hash = JSON.parse(response.body)
        rescue
          error_hash["response_error"] = "Bad response: #{response.body}"
        end
      else
        error_hash = {"response_error" => "Bad empty response: #{response}"}
      end
      return error_hash
    end

    def get(model_or_action, opts = {})
      request(:get, model_or_action, opts)
    end

    def post(model, opts = {})
      request(:create, model, opts)
    end

    def put(model, opts = {})
      request(:put, model, opts)
    end

    def delete(model, opts = {})
      request(:delete, model, opts)
    end
  end
end
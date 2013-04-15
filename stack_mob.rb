#!/usr/bin/env ruby
require 'optparse'
require 'erb'
require 'rubygems'
require 'csv'


$LOAD_PATH << File.dirname(__FILE__)
require 'stack_mob/config'
require 'stack_mob/oauth'
require 'stack_mob/java_class_factory'

# for --use-cache option we need to require classes that will be unmarshalled from
# the ./cache/(model)s.(sandbox|production).cache file. The capability to deal
# with these classes can be loaded by creating a local.rb file.
#
# TODO add option to easily create the cache from this script as well.
#
# For example my git-ignored local.rb file has these two lines:
#       $LOAD_PATH << Dir.pwd
#       require "meexo/meexo" 
local_capabilities_file = File.join(File.dirname(__FILE__),'local.rb')
if File.exists? local_capabilities_file
  require local_capabilities_file
end

#require 'ruby-debug'
require "pp"

begin
  require 'term/ansicolor'
  
  class Color
    extend Term::ANSIColor
  end
rescue Exception => e
end

################

class Hash
  def any_key?(array)
    array.each do |k|
      return true if self.has_key?(k) && self[k]!=nil && self[k]!=false
    end
    return false
  end
end

class String
  def camelize(first_letter_in_uppercase = true)
    if first_letter_in_uppercase
      self.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
    else
      self[0].chr.downcase + self.camelize[1..-1]
    end
  end
  
  def underscore
    word = self.to_s.dup
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
    word
  end
end

#############

class StackMobUtilityScript
  def initialize
    @options = {}
    @ansi_colors = defined?(Term::ANSIColor) # by default, use it if you got it

    optparse = OptionParser.new do|opts|
      # Set a banner, displayed at the top
      # of the help screen.
      opts.banner = "Usage: #{__FILE__} [options]"

      # Define the options, and what they do
      @options[:verbose] = false
      opts.on( '-v', '--verbose', 'Output more information' ) do
        @options[:verbose] = true
      end

      @options[:debug] = false
      opts.on( '--debug', 'Output even more information' ) do
        @options[:debug] = true
      end

      @options[:config] = nil
      opts.on( '--config configfile', 'The StackMob app config' ) do |configfile|
        @options[:config] = configfile
      end

      @options[:deployment] = "sandbox"
      opts.on( '--production', 'Use the production keys' ) do
        @options[:deployment] = "production"
      end

      @options[:version] = 0
      opts.on( '--version api_version', 'Use the specified production api version' ) do |version|
        @options[:version] = version
      end

      @options[:paginate] = nil
      opts.on( '-p', '--paginate #-#', 'The pagination range, zero based' ) do |value|
        @options[:paginate] = value
      end

      opts.on( '-C', '--no-colors', 'Don\'t output with ASNI colors' ) do
        @ansi_colors = false 
      end

      @options[:listapi] = false
      opts.on( '-l', '--listapi', 'The StackMob api for this app' ) do
        @options[:listapi] = true
      end

      @options[:push] = false
      opts.on( '--push', 'Indicates a push request' ) do
        @options[:push] = true
      end

      @options[:model] = nil
      opts.on( '-m', '--model thing', 'The StackMob model name' ) do |name|
        @options[:model] = name
      end

      @options[:id] = nil
      opts.on( '-a', '--all', 'Specifies all instance of specified model. See also --id' ) do
        @options[:id] = :all
      end
      opts.on( '-i', '--id modelid', 'Specifies instance of specified model. See also --all' ) do |model_id|
        @options[:id] = model_id
      end

      @options[:id_name] = nil
      opts.on( '--id-name id_name', 'The name of the id field for this model (defaults to <model>_id)' ) do |id_name|
        @options[:id_name] = id_name
      end

      @options[:generate] = false
      opts.on( '-g', '--generate-java', 'Generate a Java class skeleton for model' ) do
        @options[:generate] = true
      end

      @options[:read] = false
      opts.on( '-r', '--read', 'Read action' ) do
        @options[:read] = true
      end

      @options[:create] = false
      opts.on( '-c', '--create', 'Create action, combine with --json' ) do
        @options[:create] = true
      end

      @options[:update] = false
      opts.on( '-u', '--update', 'Update action, combine with --json' ) do
        @options[:update] = true
      end

      @options[:delete] = false
      opts.on( '-d', '--delete', 'Delete action' ) do
        @options[:delete] = true
      end

      @options[:force_post] = false
      opts.on( '-P', '--post', 'Force custom method to use POST' ) do
        @options[:force_post] = true
      end

      @options[:yes_delete] = false
      opts.on( '--yes', 'Yes, delete all!' ) do
        @options[:yes_delete] = true
      end

      @options[:login] = nil
      opts.on( '--login username/password', 'Log in action, specify username slash password or else specify a fb_at' ) do |credentials|
        @options[:login] = credentials
      end

      @options[:logout] = false
      opts.on( '--logout', 'Log out action' ) do
        @options[:logout] = true
      end

      @options[:selection_properties] = nil
      opts.on( '-S', '--selection-properties pro1,prop2,..', 'Filter out non-matching properties' ) do |props|
        @options[:selection_properties] = props.split(/,/)
      end

      @options[:method] = nil
      opts.on( '-M', '--method method', 'Custom method action, combine with --json if necessary' ) do |method|
        @options[:method] = method
      end

      @options[:expand] = nil
      opts.on( '-X', '--expand count', 'Expand relationships depth' ) do |value|
        @options[:expand] = value
      end

      @options[:long_output] = false
      opts.on( '-L', '--long', 'Long output (pretty print)' ) do
        @options[:long_output] = true
      end

      @options[:csv] = false
      opts.on( '--csv', 'CSV output' ) do
        @options[:csv] = true
      end

      @options[:use_cache] = false
      opts.on( '--use-cache', 'Use cache dir instead of stackmob for model reads' ) do
        @options[:use_cache] = true
      end

      @options[:json] = nil
      opts.on( '-j', '--json file-or-string', 'JSON file or string containing the request params or model properties' ) do |file_or_string|
        if File.exists?(file_or_string)
          begin
            File.open(file_or_string, 'r') do |f|
              contents = f.readlines.join
              if file_or_string =~ /\.erb$/
                template = ERB.new(contents)
                contents = template.result
              end
              @options[:json] = contents
            end
          rescue Exception => ex
            p ex
            exit
          end
        else
          if file_or_string =~ /\.json(\.erb)?$/
            puts "WARNING: no json file '#{file_or_string}'"
          end
          @options[:json] = file_or_string
        end
      end

      opts.on( '-J', '--json-param-string string', 'Special CGI escape conversion for custom code GET' ) do |string|
        # there should be one key and one value in a hash. The value will be turned into a json string and cgi escaped
        # so that it will form a correct custom code GET. This kludge should go away when stackmob supports custom code POST, etc
        begin
          hash = JSON.parse(string)
        rescue JSON::ParserError => err
          puts "Bad -J data"
          p err
          exit
        end
        
        unless hash.is_a? Hash
          puts "Bad format (not a hash) for -J option"
          exit
        end
        
        unless hash.keys.size == 1
          puts "Bad format (need exactly one key) for -J option"
          exit
        end

        key = hash.keys.first
        value = hash[key]
        param_value = CGI::escape value.to_json
        @options[:json] = ({ hash.keys.first => param_value}).to_json
        @options[:custom_code_json] = true
      end

      @options[:date_string] = false
      opts.on( '--date-string', 'Convert dates numbers to strings in output' ) do
        @options[:date_string] = true
      end

      @options[:sort_by] = nil
      opts.on( '-s', '--sort-by field', 'Sort output by field' ) do |field|
        @options[:sort_by] = field
      end

      
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
    end
    
    optparse.parse!
    
    if @options[:debug]
      puts "Options:"
      pp @options
    end
  end
  
  def dump_csv(results)
    # pick out all keys
    keys = []
    results.each do |hash|
      keys += hash.keys
      keys.uniq!
    end

    puts CSV.generate { |csv| csv << keys }
    
    results.each do |hash|
      hash.each do |k, v|
        hash[k] = options_transform(k, v)
      end
      puts CSV.generate { |csv| csv << keys.map{ |key| hash[key] } }
    end
  end

  def options_transform(k,v)
    if @options[:date_string]
      if k =~ /date$/
        time = Time.at v.to_i/1000.0
      elsif k =~ /_time$/
        time = Time.at v.to_i
      end
      unless time.nil?
        v = time.strftime "%z %Y-%m-%d %H:%M:%S"
      end
    end
    return v
  end
  
  def dump_results(result)
    return if result.nil?

    result = [result] if result.is_a?(Hash)

    if @options[:sort_by]
      field = @options[:sort_by]
      if result.any? { |h| h[field].nil? }
        puts "Error: at least some of sort field #{field} are nil, so unable to sort."
        exit
      else
        result.sort! { |a,b| a[field] <=> b[field] }
      end
    end

    if @options[:csv]
      dump_csv result
      return
    end

    result.each do |hash|
        puts "--"
        if hash.keys.length>0
            max_length = hash.keys.max_by{ |k| k.length }.length
            hash.each do |k,v|
              v = options_transform(k, v)
              output_row = sprintf("%#{max_length+1}s %s", k, v)

              if @ansi_colors
                if k =~ /error/ || k =~ /^debug$/ || k =~ /^remove/
                  output_row = Color.red( output_row )
                elsif k == 'sm_owner'
                  output_row = Color.cyan( output_row )
                elsif k =~ /_id$/
                  output_row = Color.yellow( output_row )
                end
              end
              puts output_row
            end
        else
          puts 'empty response hash'
        end
      end
    puts "----\nTotal: #{result.length}"
  end
  
  def filter_properties(array, properties)
    array.each do |hash|
      hash.select! { |key, value| properties.include?(key) }
    end
  end
  
  def get_all_with_pagination(stackmob, model, selection_properties)
    pagination_size = 500
    instance_hashes = []
    pagination_start = 0

    id_field_name = opts[:id_name].nil? ? "#{model}_id" : opts[:id_name]

    pagination_next = pagination_start + pagination_size
    range = "#{pagination_start}-#{pagination_next-1}"
    STDERR.puts "GET #{model} #{range}"
    result_array = stackmob.get(model, :id_name => :all, :paginate => range, :order_by => id_field_name )
    
    while result_array && result_array.is_a?(Array) && !result_array.empty?
      STDERR.puts "GOT #{result_array.size}"
      if selection_properties
        filter_properties(result_array, selection_properties)
      end
      pagination_start = pagination_next
      instance_hashes += result_array

      pagination_next = pagination_start + pagination_size
      range = "#{pagination_start}-#{pagination_next-1}"
      STDERR.puts "GET #{model} #{range}"
      result_array = stackmob.get(model, :id_name => :all, :paginate => range, :order_by => id_field_name )
    end
    STDERR.puts "TOTAL IS #{instance_hashes.size}"
    return instance_hashes
  end
  
  def get_from_cache(model, options)
    STDERR.puts "Missiong options" unless options
    cache_filename = "cache/#{model}s.#{options[:deployment]}.cache" # model+'s' is convention!
    result = nil
    if File.exists? cache_filename
       File.open(cache_filename, 'rb') do |file|
         STDERR.puts "Unpacking #{cache_filename}"
         result = Marshal.load(file)
       end
    else
      STDERR.puts "Cannot use cache, no such file: #{cache_filename}"
      exit
    end
    if result.is_a? Hash
      # should be a hash of {model_id => model, ...}
      result = result.values
    end
    hashes = result.map do |model|
      if model.is_a? Meexo::Model
        model.to_hash
      else
        pp model # bad cache!
        exit
        nil
      end
    end
    hashes
  end
  
  def run
    unless @options.any_key? [:model,:listapi,:method,:push,:login,:logout]
      puts "Not enough options specified. Need -m, -M or -l at minimum. Try -h"
      exit
    end

    if @options[:config].nil?
      ['config.json', File.join(File.dirname(__FILE__),'config.json')].each do |filename|
        if File.exists?(filename)
          @options[:config] = filename 
          break
        else
          puts "Warning, no config. Tried #{filename}"
        end
      end
      
    end
    
    puts "Using config: #{@options[:config]}" if @options[:verbose]
    config = StackMob::Config.new( File.join(@options[:config]) )

    @options[:version] = 1 if @options[:deployment] == 'production' && @options[:version] == 0
    
    sm = StackMob::Oauth.new(config, @options[:deployment], @options[:version], @options[:verbose])

    if @options[:listapi]
      result = sm.get 'listapi'
      dump_results(result)
    elsif method = @options[:method]
      opts = @options.select {|k,v| [:json, :custom_code_json, :deployment].include?(k) }
      if @options[:force_post]
        result = sm.post(method, opts)
      else
        result = sm.get(method, opts)
      end
      dump_results(result)
    else
      valid_actions = [:read,:delete,:create,:update,:login,:logout,:generate]
      unless @options.any_key? valid_actions
        puts "Need to specify an action option #{valid_actions.inspect}"
        exit
      end

      if @options[:push]
        opts = @options.select {|k,v| [:deployment, :json].include?(k) }
        result = sm.post(:push, opts)
        dump_results(result)
      elsif @options[:login]
        (username, password) = @options[:login].split(/\//)
        if password.nil?
          # assuming it is a fb_at
          opts = @options.select {|k,v| [:deployment].include?(k) }
          opts[:json] = %Q({"fb_at":"#{@options[:login]}"})
          result = sm.get('user/facebookLogin', opts)
        else
          opts = @options.select {|k,v| [:deployment, :id_name].include?(k) }
          opts[:model_id] = CGI.escape(username)
          opts[:password] = CGI.escape(password)
          result = sm.get(@options[:model], opts)
        end
        dump_results(result)
      elsif @options[:logout]
        opts = @options.select {|k,v| [:deployment].include?(k) }
        opts[:logout] = true
        result = sm.get(@options[:model], opts)
        dump_results(result)
      elsif @options[:read]
        if @options[:id] != :all
          opts = @options.select {|k,v| [:deployment, :id_name, :paginate].include?(k) }
          opts[:model_id] = @options[:id]
          if @options[:use_cache]
            # TODO this logic is also in the oauth class. Should be extracted.
            id_field_name = opts[:id_name].nil? ? "#{@options[:model]}_id" : opts[:id_name]
            # TODO get_from_cache should just handle these options itself
            instances = get_from_cache(@options[:model], opts)
            result = instances.find {|model_hash| model_hash[id_field_name] == opts[:model_id] }
          else
            opts[:expand_depth] = @options[:expand]
            result = sm.get(@options[:model], opts)
          end
          dump_results(result)
        else
          if @options[:use_cache]
            instances = get_from_cache(@options[:model], @options)
          else
            instances = get_all_with_pagination(sm, @options[:model], @options[:selection_properties])
          end
          dump_results(instances)
        end
      elsif @options[:create]
        opts = @options.select {|k,v| [:deployment, :json].include?(k) }
        result = sm.post(@options[:model], opts)
        dump_results(result)
      elsif @options[:update]
        opts = @options.select {|k,v| [:deployment, :json].include?(k) }
        result = sm.put(@options[:model], opts)
        dump_results(result)
      elsif @options[:delete]
        if @options[:id] != :all
          opts = @options.select {|k,v| [:deployment, :id_name].include?(k) }
          opts[:model_id] = @options[:id]
          result = sm.delete(@options[:model], opts)
          dump_results(result)
        else
          instances = get_all_with_pagination(sm, @options[:model], @options[:selection_properties])
          if (instances.length > 0)
            unless @options[:yes_delete]
              puts "Are you sure you want to delete all #{instances.size} instances of #{@options[:model]}? (yes|NO)"
              user_response = STDIN.gets.strip
              user_response = '[nothing]' if user_response == ''
              @options[:yes_delete] = true if user_response == 'yes'
            end

            if @options[:yes_delete]
              id_param = @options[:id_name].nil? ? "#{@options[:model]}_id" : @options[:id_name]
              instances.each do |instance|
                model_id = instance[id_param]
                puts "Deleting #{@options[:model]} #{model_id}"
                opts = @options.select {|k,v| [:deployment, :id_name].include?(k) }
                opts[:model_id] = model_id
                result = sm.delete(@options[:model], opts)
                dump_results(result)
              end
            else
              puts "Ok, not deleting every #{@options[:model]}. Whew, that was close."
            end
          else
            puts "No instances of #{@options[:model]} to delete."
          end
        end
      elsif @options[:generate]
        # get all model api
        opts = @options.select {|k,v| [:deployment].include?(k) }
        result = sm.get 'listapi', opts
        modelHash = result[@options[:model]]
        if modelHash.nil?
          puts "Unable to find API for Model \"#{@options[:model]}\""
          exit
        end
        
        jcf = JavaClassFactory.new(modelHash)
        jcf.class_source
      end
    end
  end
end

if __FILE__ == $0
  ARGV << '-h' if ARGV.length == 0
    
  script = StackMobUtilityScript.new
  script.run
end

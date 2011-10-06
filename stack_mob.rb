#!/usr/bin/env ruby
require 'optparse'
require 'erb'
require 'rubygems'


$LOAD_PATH << File.dirname(__FILE__)
require 'stack_mob/config'
require 'stack_mob/oauth'
require 'stack_mob/java_class_factory'

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

      @options[:yes_delete] = false
      opts.on( '--yes', 'Yes, delete all!' ) do
        @options[:yes_delete] = true
      end

      @options[:login] = nil
      opts.on( '--login username/password', 'Log in action, specify username slash password' ) do |credentials|
        @options[:login] = credentials
      end

      @options[:logout] = false
      opts.on( '--logout', 'Log out action' ) do
        @options[:logout] = true
      end

      @options[:method] = nil
      opts.on( '-M', '--method method', 'Custom method action, combine with --json if necessary' ) do |method|
        @options[:method] = method
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
    
    result.each do |hash|
      puts '--'
      if hash.keys.length>0
        max_length = hash.keys.max_by{ |k| k.length }.length
        hash.each do |k,v|
          v = v.inspect unless k == 'trace' # this allows the \n in the debug trace to be rendered properly, but nil things will get nil instead of blank
        
          if k =~ /date$/ && @options[:date_string]
            time = Time.at v.to_i/1000.0
            unless time.nil?
              v = time.strftime "%z %Y-%m-%d %H:%M:%S"
            end
          end
        
          output_row = sprintf("%#{max_length+1}s %s", k, v)

          if @ansi_colors
            if k =~ /error/ || k =~ /^debug$/
              output_row = Color.red( output_row )
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
  
  def run
    unless @options.any_key? [:model,:listapi,:method,:push]
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
      result = sm.get(method, :json => @options[:json])
      dump_results(result)
    else
      valid_actions = [:read,:delete,:create,:update,:login,:logout,:generate]
      unless @options.any_key? valid_actions
        puts "Need to specify an action option #{valid_actions.inspect}"
        exit
      end

      if @options[:push]
        result = sm.post(:push, :json => @options[:json])
        dump_results(result)
      elsif @options[:login]
        (username, password) = @options[:login].split(/\//)
        result = sm.get(@options[:model], :model_id => username, :id_name => @options[:id_name], :password => password)
        dump_results(result)
      elsif @options[:logout]
        result = sm.get(@options[:model], :logout => true)
        dump_results(result)
      elsif @options[:read]
        result = sm.get(@options[:model], :model_id => @options[:id], :id_name => @options[:id_name])
        dump_results(result)
      elsif @options[:create]
        result = sm.post(@options[:model], :json => @options[:json])
        dump_results(result)
      elsif @options[:update]
        result = sm.put(@options[:model], :json => @options[:json])
        dump_results(result)
      elsif @options[:delete]
        if @options[:id] != :all
          result = sm.delete(@options[:model], :model_id => @options[:id], :id_name => @options[:id_name])
          dump_results(result)
        else
          instances = sm.get(@options[:model], :model_id => :all)
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
                puts "Deleting #{model_id}"
                result = sm.delete(@options[:model], :model_id => model_id, :id_name => @options[:id_name])
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
        #result = sm.get 'listapi'
        result = JSON.parse "{\"product\":{\"type\":\"object\",\"properties\":{\"custom_integer_array\":{\"optional\":true,\"type\":\"array\",\"indexed\":false,\"title\":\"custom_integer_array\",\"description\":\"custom_integer_array\",\"items\":{\"type\":\"integer\"}},\"product_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"product_id\",\"identity\":true},\"custom_string_array\":{\"optional\":true,\"type\":\"array\",\"indexed\":false,\"title\":\"custom_string_array\",\"description\":\"custom_string_array\",\"items\":{\"type\":\"string\"}},\"description\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"description\",\"description\":\"description\"},\"name\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"name\",\"description\":\"name\"},\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"price_paid_currency\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"price_paid_currency\",\"description\":\"price_paid_currency\"},\"price_earned_currency\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"price_earned_currency\",\"description\":\"price_earned_currency\"},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"},\"class_name\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"class_name\",\"description\":\"class_name\"}},\"id\":\"product\"},\"message\":{\"type\":\"object\",\"properties\":{\"content\":{\"optional\":false,\"type\":\"string\",\"indexed\":false,\"title\":\"content\",\"description\":\"content\"},\"flags\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"flags\",\"description\":\"flags\"},\"from_profile_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"from_profile_id\",\"description\":\"from_profile_id\"},\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"to_profile_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"to_profile_id\",\"description\":\"to_profile_id\"},\"message_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"message_id\",\"identity\":true},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"}},\"id\":\"message\"},\"invitation_code\":{\"type\":\"object\",\"properties\":{\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"},\"user\":{\"optional\":true,\"type\":\"string\",\"$ref\":\"user\"},\"invitation_code_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"invitation_code_id\",\"identity\":true}},\"id\":\"invitation_code\"},\"device\":{\"type\":\"object\",\"properties\":{\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"device_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"device_id\",\"identity\":true},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"},\"user\":{\"optional\":true,\"type\":\"string\",\"$ref\":\"user\"}},\"id\":\"device\"},\"conversation\":{\"type\":\"object\",\"properties\":{\"receiver_profile\":{\"optional\":true,\"type\":\"string\",\"$ref\":\"message\"},\"level\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"level\",\"description\":\"level\"},\"conversation_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"conversation_id\",\"identity\":true},\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"initiator_profile\":{\"optional\":true,\"type\":\"string\",\"$ref\":\"profile\"},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"},\"messages\":{\"optional\":true,\"type\":\"array\",\"$ref\":\"message\",\"items\":{\"type\":\"string\",\"$ref\":\"message\"}}},\"id\":\"conversation\"},\"user\":{\"type\":\"object\",\"properties\":{\"invited_code\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"invited_code\",\"description\":\"invited_code\"},\"invitation_code\":{\"optional\":true,\"type\":\"string\",\"$ref\":\"invitation_code\"},\"profile_id\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"profile_id\",\"description\":\"profile_id\"},\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"login\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"login\",\"format\":\"username\",\"identity\":true,\"description\":\"login\"},\"device_tokens\":{\"optional\":true,\"type\":\"array\",\"indexed\":false,\"title\":\"device_tokens\",\"description\":\"device_tokens\",\"items\":{\"type\":\"string\"}},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"},\"password\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"password\",\"format\":\"password\",\"description\":\"password\"},\"profile\":{\"optional\":true,\"type\":\"string\",\"$ref\":\"profile\"}},\"id\":\"user\"},\"wallet\":{\"type\":\"object\",\"properties\":{\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"wallet_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"wallet_id\",\"identity\":true},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"},\"experience_points\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"experience_points\",\"description\":\"experience_points\"},\"paid_currency\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"paid_currency\",\"description\":\"paid_currency\"},\"earned_currency\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"earned_currency\",\"description\":\"earned_currency\"}},\"id\":\"wallet\"},\"selection\":{\"type\":\"object\",\"properties\":{\"selection_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"selection_id\",\"identity\":true},\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"profiles\":{\"optional\":true,\"type\":\"array\",\"$ref\":\"profile\",\"items\":{\"type\":\"string\",\"$ref\":\"profile\"}},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"}},\"id\":\"selection\"},\"profile\":{\"type\":\"object\",\"properties\":{\"profile_id\":{\"optional\":false,\"type\":\"string\",\"indexed\":true,\"title\":\"profile_id\",\"identity\":true},\"diet\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"diet\",\"description\":\"diet\"},\"similarity_venues\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"similarity_venues\",\"description\":\"similarity_venues\"},\"about\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"about\",\"description\":\"about\"},\"similarity_music\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"similarity_music\",\"description\":\"similarity_music\"},\"children\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"children\",\"description\":\"children\"},\"education\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"education\",\"description\":\"education\"},\"relationship_status\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"relationship_status\",\"description\":\"relationship_status\"},\"drinks\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"drinks\",\"description\":\"drinks\"},\"messages\":{\"optional\":true,\"type\":\"array\",\"$ref\":\"message\",\"items\":{\"type\":\"string\",\"$ref\":\"message\"}},\"religion\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"religion\",\"description\":\"religion\"},\"photo_paths\":{\"optional\":true,\"type\":\"array\",\"indexed\":false,\"title\":\"photo_paths\",\"description\":\"photo_paths\",\"items\":{\"type\":\"string\"}},\"height\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"height\",\"description\":\"height\"},\"income\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"income\",\"description\":\"income\"},\"name\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"name\",\"description\":\"name\"},\"pets\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"pets\",\"description\":\"pets\"},\"birthdate\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"birthdate\",\"description\":\"birthdate\"},\"gender\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"gender\",\"description\":\"gender\"},\"seeking_genders\":{\"optional\":true,\"type\":\"array\",\"indexed\":false,\"title\":\"seeking_genders\",\"description\":\"seeking_genders\",\"items\":{\"type\":\"string\"}},\"cooking\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"cooking\",\"description\":\"cooking\"},\"occupation\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"occupation\",\"description\":\"occupation\"},\"user_login\":{\"optional\":true,\"type\":\"string\",\"$ref\":\"user\"},\"phone_type\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"phone_type\",\"description\":\"phone_type\"},\"similarity_tags\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"similarity_tags\",\"description\":\"similarity_tags\"},\"lastmoddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Last Modified Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was modified\"},\"createddate\":{\"type\":\"integer\",\"indexed\":true,\"readonly\":true,\"title\":\"Created Timestamp\",\"format\":\"utcmillisec\",\"description\":\"UTC time when the entity was created\"},\"profile_photo_path\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"profile_photo_path\",\"description\":\"profile_photo_path\"},\"invitation_code\":{\"optional\":true,\"type\":\"string\",\"$ref\":\"invitation_code\"},\"email\":{\"optional\":true,\"type\":\"string\",\"indexed\":false,\"title\":\"email\",\"description\":\"email\"},\"astrological_sign\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"astrological_sign\",\"description\":\"astrological_sign\"},\"ethnicity\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"ethnicity\",\"description\":\"ethnicity\"},\"smokes\":{\"optional\":true,\"type\":\"integer\",\"indexed\":false,\"title\":\"smokes\",\"description\":\"smokes\"}},\"id\":\"profile\"}}"
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

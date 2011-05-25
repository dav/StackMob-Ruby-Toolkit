#!/usr/bin/env ruby
require 'optparse'
require 'erb'
require 'rubygems'

$LOAD_PATH << File.dirname(__FILE__)
require 'stack_mob_config'
require 'stack_mob_oauth'

#require 'ruby-debug'
require "pp"

begin
  require 'term/ansicolor'
  
  class Color
    extend Term::ANSIColor
  end
rescue Exception => e
end

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

      opts.on( '-C', '--no-colors', 'Don\'t output with ASNI colors' ) do
        @ansi_colors = false 
      end

      @options[:listapi] = false
      opts.on( '-l', '--listapi', 'The StackMob api for this app' ) do
        @options[:listapi] = true
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

      @options[:read] = false
      opts.on( '-r', '--read', 'Read action' ) do
        @options[:read] = true
      end

      @options[:create] = false
      opts.on( '-c', '--create', 'Create action, combine with --json' ) do
        @options[:create] = true
      end

      @options[:delete] = false
      opts.on( '-d', '--delete', 'Delete action' ) do
        @options[:delete] = true
      end

      @options[:login] = nil
      opts.on( '--login username/password', 'Login action, specify username slash password' ) do |credentials|
        @options[:login] = credentials
      end


      @options[:method] = nil
      opts.on( '-M', '--method method', 'Custom method action, combine with --json if necessary' ) do |method|
        @options[:method] = method
      end

      @options[:json] = nil
      opts.on( '-j', '--json file', 'JSON file containing the request params or model properties' ) do |file|
        begin
          File.open(file, 'r') do |f|
            contents = f.readlines.join
            if file =~ /\.erb$/
              template = ERB.new(contents)
              contents = template.result
            end
            @options[:json] = contents
          end
        rescue Exception => ex
          p ex
          exit
        end
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
    end
    
    optparse.parse!
  end
  

  def dump_results(result)
    return if result.nil?
    
    result = [result] if result.is_a?(Hash)
    
    result.each do |hash|
      puts '--'
      max_length = hash.keys.max_by{ |k| k.length }.length
      hash.each do |k,v|
        output_row = sprintf("%#{max_length+1}s %s", k, v.inspect)

        if @ansi_colors
          if k =~ /error/ || k =~ /^debug$/
            output_row = Color.red( output_row )
          elsif k =~ /_id$/
            output_row = Color.yellow( output_row )
          end
        end
        puts output_row
      end
      
    end
    puts "----\nTotal: #{result.length}" 
  end
  
  def run
    unless @options[:model] || @options[:listapi] || @options[:method]
      puts "Not enough options specified. Need -m, -M or -l at minimum. Try -h"
      exit
    end

    config = StackMobConfig.new( File.join(File.dirname(__FILE__),'config.json') )

    sm = StackMobOauth.new(config, @options[:verbose])

    if @options[:listapi]
      result = sm.get 'listapi'
      dump_results(result)
    elsif method = @options[:method]
      result = sm.get(method, :json => @options[:json])
      dump_results(result)
    else
      unless @options[:read] || @options[:delete] || @options[:create] || @options[:login]
        puts "Need to specify an action option (read, delete, create or login)"
        exit
      end

      if @options[:login]
        (login, password) = @options[:login].split(/\//)
        result = sm.get(@options[:model], :model_id => login, :id_name => @options[:id_name], :password => password)
        dump_results(result)
      elsif @options[:read]
        result = sm.get(@options[:model], :model_id => @options[:id])
        dump_results(result)
      elsif @options[:create]
        result = sm.post(@options[:model], :json => @options[:json])
        dump_results(result)
      elsif @options[:delete]
        if @options[:id] != :all
          result = sm.delete(@options[:model], :model_id => @options[:id], :id_name => @options[:id_name])
          dump_results(result)
        else
          instances = sm.get(@options[:model], :model_id => :all)
          puts "Are you sure you want to delete all #{instances.size} instances of #{@options[:model]}? (yes|NO)"
          user_response = STDIN.gets.strip
          user_response = '[nothing]' if user_response == ''
          if user_response == 'yes'
            id_param = @options[:id_name].nil? ? "#{@options[:model]}_id" : @options[:id_name]
            instances.each do |instance|
              model_id = instance[id_param]
              puts "Deleting #{model_id}"
              result = sm.delete(@options[:model], :model_id => model_id, :id_name => @options[:id_name])
              dump_results(result)
            end
          else
            puts "Ok, #{user_response}!=yes, so not deleting everything. Whew."
          end
        end
      end
    end
  end
end

if __FILE__ == $0
  script = StackMobUtilityScript.new
  script.run
end
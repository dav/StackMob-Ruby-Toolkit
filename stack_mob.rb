#!/usr/bin/env ruby
require 'optparse'
require 'erb'
require 'rubygems'

require 'stack_mob_config'
require "stack_mob_oauth"

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
    max_length = result.keys.max_by{ |k| k.length }.length
    result.each do |k,v|
      output_row = sprintf("%#{max_length+1}s %s", k, v)
      
      if @ansi_colors
        if k =~ /error/
          output_row = Color.red( output_row )
        elsif k =~ /_id$/
          output_row = Color.yellow( output_row )
        end
      end
      puts output_row
    end
  end
  
  def run
    unless @options[:model] || @options[:listapi] || @options[:method]
      puts "Not enough options specified. Need -m, -M or -l at minimum. Try -h"
      exit
    end

    config = StackMobConfig.new

    sm = StackMobOauth.new(config, @options[:verbose])

    if @options[:listapi]
      result = sm.get 'listapi'
      dump_results(result)
    elsif method = @options[:method]
      result = sm.get(method, :json => @options[:json])
      dump_results(result)
    else
      unless @options[:read] || @options[:delete] || @options[:create]
        puts "Need to specify an action option (read, delete or create)"
        exit
      end

      if @options[:read]
        result = sm.get(@options[:model], :model_id => @options[:id])
        dump_results(result)
      elsif @options[:create]
        result = sm.post(@options[:model], :json => @options[:json])
        dump_results(result)
      elsif @options[:delete]
        if @options[:id] != :all
          result = sm.delete(@options[:model], :model_id => @options[:id])
          dump_results(result)
        else
          instances = sm.get(@options[:model], :model_id => :all)
          puts "Are you sure you want to delete all #{instances.size} instances of #{@options[:model]}? (yes|NO)"
          user_response = STDIN.gets.strip
          user_response = '[nothing]' if user_response == ''
          if user_response == 'yes'
            instances.each do |instance|
              model_id = instance["#{@options[:model]}_id"]
              puts "Deleting #{model_id}"
              result = sm.delete(@options[:model], :model_id => model_id)
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
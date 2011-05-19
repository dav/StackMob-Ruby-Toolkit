#!/usr/bin/env ruby
require 'optparse'
require 'rubygems'
require 'erb'
 
require 'stack_mob_config'
require "stack_mob_oauth"

#require 'ruby-debug'
require "pp"

# This hash will hold all of the options
# parsed from the command-line by
# OptionParser.
options = {}

optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: #{__FILE__} [options]"

  # Define the options, and what they do
  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Output more information' ) do
    options[:verbose] = true
  end

  options[:listapi] = false
  opts.on( '-l', '--listapi', 'The StackMob api for this app' ) do
    options[:listapi] = true
  end

  options[:model] = nil
  opts.on( '-m', '--model thing', 'The StackMob model name' ) do |name|
    options[:model] = name
  end

  options[:id] = nil
  opts.on( '-a', '--all', 'Specifies all instance of specified model. See also --id' ) do
    options[:id] = :all
  end

  opts.on( '-i', '--id modelid', 'Specifies instance of specified model. See also --all' ) do |model_id|
    options[:id] = model_id
  end

  options[:read] = false
  opts.on( '-r', '--read', 'Read action' ) do
    options[:read] = true
  end

  options[:create] = false
  opts.on( '-c', '--create', 'Create action, combine with --json' ) do
    options[:create] = true
  end

  options[:delete] = false
  opts.on( '-d', '--delete', 'Delete action' ) do
    options[:delete] = true
  end

  options[:method] = nil
  opts.on( '-M', '--method method', 'Custom method action' ) do |method|
    options[:method] = method
  end

  options[:json] = nil
  opts.on( '-j', '--json file', 'JSON file' ) do |file|
    begin
      File.open(file, 'r') do |f|
        contents = f.readlines.join
        if file =~ /\.erb$/
          template = ERB.new(contents)
          contents = template.result
        end
        options[:json] = contents
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

unless options[:model] || options[:listapi] || [:method]
  puts "Not enough options specified. Need -m, -M or -l at minimum. Try -h"
  exit
end

config = StackMobConfig.new

sm = StackMobOauth.new(config, options[:verbose])

if options[:listapi]
  result = sm.get 'listapi'
  pp result
elsif options[:method]
  result = sm.get(options[:method], :json => options[:json])
  pp result
else
  unless options[:read] || options[:delete] || options[:create]
    puts "Need to specify an action option (read, delete or create)"
    exit
  end

  if options[:read]
    result = sm.get(options[:model], :model_id => options[:id])
    pp result
  elsif options[:create]
    result = sm.post(options[:model], :json => options[:json])
    pp result
  elsif options[:delete]
    if options[:id] != :all
      result = sm.delete(options[:model], :model_id => options[:id])
      pp result unless result.nil?
    else
      instances = sm.get(options[:model], :model_id => :all)
      puts "Are you sure you want to delete all #{instances.size} instances of #{options[:model]}? (yes|NO)"
      user_response = STDIN.gets.strip
      user_response = '[nothing]' if user_response == ''
      if user_response == 'yes'
        instances.each do |instance|
          model_id = instance["#{options[:model]}_id"]
          puts "Deleting #{model_id}"
          result = sm.delete(options[:model], :model_id => model_id)
          pp result unless result.nil?
        end
      else
        puts "Ok, #{user_response}!=yes, so not deleting everything. Whew."
      end
    end
  end
end

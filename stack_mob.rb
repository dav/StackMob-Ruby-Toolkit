#!/usr/bin/env ruby
require 'optparse'
 
require "stack_mob_oauth"
require "json"
require "pp"

def read_config(configfile='config.json')
  config = {}
  File.open(configfile, 'r') do |file|
    config = JSON.parse file.readlines.join
  end
  return config
end

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

  options[:create] = nil
  opts.on( '-c', '--create json_file', 'Create action, using specified file for instance values' ) do |json_file|
    options[:create] = json_file
  end

  options[:delete] = false
  opts.on( '-d', '--delete', 'Delete action' ) do
    options[:delete] = true
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!

unless options[:model] || options[:listapi]
  puts "Not enough options specified. Try -h"
  exit
end

config = read_config

sm = StackMobOauth.new(config)

if options[:listapi]
  result = sm.get 'listapi'
  pp result
else
  unless options[:read] || options[:delete] || options[:create]
    puts "Need to specify an action option (read, delete or create)"
    exit
  end

  if options[:read]
    result = sm.get(options[:model], options[:id])
    pp result
  elsif options[:create]
    begin
      File.open(options[:create], 'r') do |file|
        json = file.readlines.join
        result = sm.post(options[:model], json)
        pp result
      end
    rescue Exception => ex
      p ex
      exit
    end
  elsif options[:delete]
    if options[:id] != :all
      result = sm.delete(options[:model], options[:id])
      pp result unless result.nil?
    else
      instances = sm.get(options[:model], :all)
      puts "Are you sure you want to delete all #{instances.size} instances of #{options[:model]}? (yes|NO)"
      user_response = STDIN.gets.strip
      user_response = '[nothing]' if user_response == ''
      if user_response == 'yes'
        instances.each do |instance|
          model_id = instance["#{options[:model]}_id"]
          puts "Deleting #{model_id}"
          result = sm.delete(options[:model], model_id)
          pp result unless result.nil?
        end
      else
        puts "Ok, #{user_response}!=yes, so not deleting everything. Whew."
      end
    end
  end
end

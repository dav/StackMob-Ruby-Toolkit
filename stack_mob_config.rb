require 'json'

class StackMobConfig < Hash
  attr_reader :appname, :key, :secret
  
  def initialize(configfile="config.json")
    super
    
    config = {}
    File.open(configfile, 'r') do |file|
      config = JSON.parse file.readlines.join
    end
      
    @appname = config["default"]
    raise "Config is missing default app name" if @appname.nil?
    
    @key = config[@appname]["key"]
    @secret = config[@appname]["secret"]
    if @key.nil? || @secret.nil?
     raise "Config is missing key and/or secret."
    end

    self.merge! config
  end
end
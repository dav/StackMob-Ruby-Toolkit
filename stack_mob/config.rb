require 'json'

module StackMob
  class Config < Hash

    def initialize(configfile)
      super

      config = {}
      File.open(configfile, 'r') do |file|
        config = JSON.parse file.readlines.join
      end

      config["account"] || (raise "Config is missing the account name.")
      config["application"]     || (raise "Config is missing the application name")

      raise "Config is missing a set of keys." if config["sandbox"].nil? && config["production"].nil?
            
      self.merge!(config)
    end
  end
end  

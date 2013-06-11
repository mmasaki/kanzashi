module Kanzashi
  module Plugin
    include Kanzashi
    class Error < StandardError; end
    class << self; include UtilMethod; end

    PLUGINS_DIR = File.expand_path("#{File.dirname(__FILE__)}/../../plugins")
    @@plugins = {}
    @@old_plugins = nil
    
    module_function

    def list
      @@old_plugins = @@plugins.dup
      Dir[PLUGINS_DIR+"/*.rb"].each do |x|
        sym = x.match(/#{Regexp.escape(PLUGINS_DIR)}\/(.+)\.rb$/)[1].to_sym
        @@plugins[sym] = {
          checksum: Digest::SHA256.hexdigest(File.read(x)),
          path: x
        }
      end
      @@plugins
    end

    def plug(x)
      list unless @@old_plugins
      unless @@plugins.has_key?(x)
        log.warn("Plugin") { "\"#{x}\" is not found" }
        return false
      end
      load @@plugins[x][:path]
    end

    def plug_all
      config.plugins.each do |name,cfg|
        plug name if cfg.enabled
      end
    end
  end

  module Hook
    def plugin(&block)
      begin
        module_eval(&block)
      rescue
        log.error("Plugin") { ex.message }
      end
    end
    
    def self.included(obj)
      obj.extend(self)
    end
    
    def self.extended(obj)
      hooks = Hash.new {|hash, key| hash[key] = [] }
      obj.class_variable_set(:@@hooks, hooks)
    end
    
    def hooks
      self.class_variable_get(:@@hooks)
    end
  
    def on(event, &block)
      hooks[event].push(block)
    end
  
    def call_hooks(event, *args)
      event = event.to_sym unless event.is_a?(Symbol)
      hooks[event].each do |hook|
        begin
          hook.call(*args)
        rescue => ex
          log.error("Hook") { ex.message }
        end
      end
    end
  end
end

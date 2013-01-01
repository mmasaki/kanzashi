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
      Hook.make_space(x) do
        load @@plugins[x][:path]
      end
    end

    def plug_all
      config.plugins.each do |name,cfg|
        plug name if cfg.enabled
      end
    end

    module Base
      def self.included(mod)
        mod.module_eval do
          @@hooks = Hash.new {|hash, key| hash[key] = [] }
        end
      end

      module_function

      def on(name, &block)
        raise Error, "no blocks given (hook: #{name})" unless block_given?
        @@hooks[name.to_sym].push(block)
      end

      def call_hooks(name, *args)
        @@hooks[name.to_sym].each do |hook|
          hook.call(*args)
        end
      end
    end
  end
end

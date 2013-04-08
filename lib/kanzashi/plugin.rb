module Kanzashi
  def self.plugin(&block)
    Module.new do
      extend Plugin::Base
      module_eval(&block)
    end
  end

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
      @@hooks = Hash.new do |hash, key|
        hash[key] = Hash.new {|hash, key| hash[key] = [] }
      end

      module_function

      def namespace
        @namespace || :global
      end

      def from(mod, &block)
        mod = Kanzashi.const_get(mod) unless mod == Module
        Module.new do
          extend Base
          @namespace = mod
          module_exec(mod, &block)
        end
      end

      def on(name, &block)
        raise Error, "no blocks given (hook: #{name})" unless block_given?
        @@hooks[namespace][name.to_sym].push(block)
      end

      def call_hooks(namespace, name, *args)
        #hooks_to_call = @@hooks[:global][name.to_sym]
        hooks_to_call = []
        hooks_to_call.concat(@@hooks[namespace][name.to_sym]) if namespace != :global
        return if hooks_to_call.empty?
        hooks_to_call.each {|hook| hook.call(*args) }
      end
    end
  end
end

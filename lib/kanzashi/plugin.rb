module Kanzashi
  class Plugin
    include Kanzashi
    PLUGINS_DIR = File.expand_path("#{File.dirname(__FILE__)}/../plugins")
    @@plugins = {}
    @@old_plugins = nil
    class << self
      def list
        @@old_plugins = @@plugins.dup
        Dir[PLUGINS_DIR+"/*.rb"].each do |x|
          sym = x.match(/#{Regexp.escape(PLUGINS_DIR)}\/(.+)\.rb$/)[0].to_sym
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
    end
  end
end

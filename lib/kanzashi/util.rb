module Kanzashi
  module Util
    # class CustomHash and CustomArray is public domain.
    # https://gist.github.com/1668637

    class CustomHash < Hash
      def self.new(a)
        self[a]
      end

      def self.[](a)
        h = super(a.to_a)
        h.keys.select{|key| key.kind_of?(String) }.each do |key|
          h[key.to_sym] = h.delete(key)
        end
        h.each do |key,value|
          case value
          when Array
            h[key] = CustomArray.new(value)
          when Hash
            h[key] = CustomHash[value]
          end
        end
        h
      end

      def method_missing(name,*args)
        self.has_key?(name) ? self[name] : nil
      end
    end

    class CustomArray < Array
      def initialize(*args)
        super *args
        self.map! do |x|
          if x.kind_of?(Hash) && x.class != CustomHash
            CustomHash.new(x)
          else; x; end
        end
      end
    end
  end

  module UtilMethod
    def config
      Config.config
    end

    def log
      Log.logger
    end
  end

  class Log
    include Kanzashi
    class << self; include UtilMethod; end

    DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S "

    @@logger = nil

    def self.logger
      unless @@logger
        @@logger = Logger.new(config.log.output||STDOUT)
        @@logger.level = config.log.level if config.log.level
        @@logger.datetime_format = DATETIME_FORMAT
      end
      @@logger
    end

  end

  include UtilMethod
  class << self
    include UtilMethod
    def c
      namespace = caller.any?{|x| /in `make_space'/ =~ x && x.start_with?(Kanzashi::Hook::FILE) } ? \
        Kanzashi::Hook.namespace : nil
      namespace = nil if namespace == :global

      unless namespace
        a = false
        begin
          namespace = caller.reverse.map{|x| x.match(
            /#{Regexp.escape(Kanzashi::Plugin::PLUGINS_DIR)}\/(.+).rb:\d+:in `.+'/
          ) }.compact[0][1].to_sym
        rescue NoMethodError; end
      end
      namespace = :global unless namespace

      config.plugins[namespace]
    end
  end
end


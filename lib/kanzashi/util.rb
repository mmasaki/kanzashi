module Kanzashi
  module Util
    class CustomHash < Hash
      class << self
        undef new
        def new(a)
          self[a]
        end
      end

      def self.[](a)
        h = (super a.to_a)
        h.keys.select{|key| key.kind_of?(String) }.each do |key|
          h[key.to_sym] = h.delete(key)
        end
        h.each do |key,value|
          case value
          when Array
            h[key] = CustomArray.new(value)
          when Hash
            h[key] = CustomHash.new(value)
          end
        end
        h
      end

      def method_missing(name,*args)
        self.has_key?(name) ? self[name] : super
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
  end
  include UtilMethod
  class << self; include UtilMethod; end
end


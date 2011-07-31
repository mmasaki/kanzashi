module Kanzashi
  module Hook
    @@lock = Mutex.new
    @@namespace = :global
    @@hooks = {}
    class << self
      include Kanzashi
      include UtilMethod

      def make_space(name)
        raise ArgumentError, "can't make :global" if name == :global

        @@lock.synchronize do
          @@namespace = name
          @@hooks.delete(name)
          yield
          @@namespace = :global
        end
      end

      def hook(name,&hook)
        namespace = caller.any?{|x| /in `make_space'/ =~ x && x.start_with?(__FILE__) } ? \
          @@namespace : :global
        @@hooks[namespace] ||= {}
        @@hooks[namespace][name] ||= []
        @@hooks[namespace][name] << hook
        self
      end

      def call_with_namespace(name,namespace,*args)
        call_(name,args,namespace)
      end

      def call(name,*args)
        call_(name,args)
      end

      def call_(type,args,namespace=nil)
        #log.debug("Hook:call") {"#{type}(#{args.inspect}) @ #{namespace||"global"}"}
        @@hooks.each do |name, space|
          next if !namespace.nil? && name != namespace
          space.each do |t, hooks|
            next unless type == t
            hooks.each do |hook|
              hook.call *args
            end
          end
        end
      end

      def method_missing(name,*args,&block)
        hook(name,&block)
      end

      def remove_space(name)
        raise ArgumentError, "can't remove :global" if name == :global
        @@hooks.delete(name)
        self
      end
    end
  end
end

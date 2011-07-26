module Kanzashi
  module Hook
    @@lock = Mutex.new
    @@namespace = :global
    @@hooks = {}
    class << self
      def make_space(name)
        @@lock.synchronize do
          @@namespace = name
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

      def call_(name,args,namespace=nil)
        @@hooks.each do |name, space|
          next if !namespace.nil? && name != namespace
          space.each do |type, hooks|
            hooks.each do |hook|
              hook.call *args
            end
          end
        end
      end

      def method_missing(name,*args,&block)
        hook(name,&block)
      end
    end
  end
end

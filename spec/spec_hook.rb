require_relative './helper'

describe Kanzashi::Hook do
  describe ".hook" do
    it "adds hook block to @@hooks" do
      Kanzashi::Hook.hook(:for_test_a) { a = true }
      hooks = Kanzashi::Hook.class_variable_get(:"@@hooks")
      hooks[:global][:for_test_a].size.should == 1
    end

    it "called by method_missing" do
      Kanzashi::Hook.missing { a = true }
      hooks = Kanzashi::Hook.class_variable_get(:"@@hooks")
      hooks[:global][:missing].size.should == 1
    end
  end

  describe ".call" do
    it "calls all hooks" do
      a = []
      Kanzashi::Hook.hook(:for_test_b) { a << true }
      Kanzashi::Hook.hook(:for_test_b) { a << true }
      Kanzashi::Hook.call(:for_test_b)
      a.size.should == 2
    end

    it "calls with argument" do
      a = nil
      Kanzashi::Hook.hook(:for_test_c) {|arg| a = arg }
      Kanzashi::Hook.call(:for_test_c, :test)
      a.should == :test
    end

    it "calls with arguments" do
      a = nil
      Kanzashi::Hook.hook(:for_test_d) {|*arg| a = arg }
      Kanzashi::Hook.call(:for_test_d, :foo, :bar)
      a.should == [:foo, :bar]
    end
  end

  describe ".call_with_namespace" do
    it "calls all hooks of specified namespace" do
      a = false
      Kanzashi::Hook.make_space(:test_a) do
        Kanzashi::Hook.hook(:for_test_e){ a = true }
      end
      Kanzashi::Hook.call_with_namespace(:for_test_e, :test_a)
      a.should be_true
    end

    it "calls with argument" do
      a = nil
      Kanzashi::Hook.make_space(:test_b) do
        Kanzashi::Hook.hook(:for_test_f){|arg| a = arg }
      end
      Kanzashi::Hook.call_with_namespace(:for_test_f, :test_b, :foo)
      a.should == :foo
    end

    it "calls with arguments" do
      a = nil
      Kanzashi::Hook.make_space(:test_c) do
        Kanzashi::Hook.hook(:for_test_g){|*arg| a = arg }
      end
      Kanzashi::Hook.call_with_namespace(:for_test_g, :test_c, :foo, :bar)
      a.should == [:foo, :bar]
    end
  end

  describe ".make_space" do
    it "makes namespace" do
      Kanzashi::Hook.make_space(:test_d) do
        Kanzashi::Hook.hook(:test_namespace_example){ :that_make_nothing }
      end
      hooks = Kanzashi::Hook.class_variable_get(:"@@hooks")
      hooks[:test_d][:test_namespace_example].size.should == 1
    end

    it "removes old hooks" do
      a = false
      Kanzashi::Hook.make_space(:test_remove) do
        Kanzashi::Hook.hook(:hi){ a = true }
      end
      Kanzashi::Hook.make_space(:test_remove) {}
      Kanzashi::Hook.call(:hi)
      a.should_not be_true
    end

    it "is thread-safe" do
      a = Thread.new {
        Kanzashi::Hook.make_space(:test_e) do
          Kanzashi::Hook.hook(:test_namespace_example){ :that_make_nothing }
        end
      }
      Kanzashi::Hook.make_space(:test_f) do
        Kanzashi::Hook.hook(:test_namespace_example){ :that_make_nothing }
      end
      a.join
      hooks = Kanzashi::Hook.class_variable_get(:"@@hooks")
      hooks[:test_e][:test_namespace_example].size.should == 1
      hooks[:test_f][:test_namespace_example].size.should == 1
    end

    it "raises error when making :global space" do
      ->{ Kanzashi::Hook.make_space(:global) }.should raise_error(ArgumentError)
    end
  end

  describe ".remove_space" do
    it "removes namespace" do
      Kanzashi::Hook.make_space(:test_remove) {}
      Kanzashi::Hook.remove_space(:test_remove)
      hooks = Kanzashi::Hook.class_variable_get(:"@@hooks")
      hooks.has_key?(:test_remove).should_not be_true
    end

    it "raises error when removing :global" do
      ->{ Kanzashi::Hook.remove_space(:global) }.should raise_error(ArgumentError)
    end
  end
end

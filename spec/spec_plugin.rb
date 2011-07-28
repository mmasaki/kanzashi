require_relative './helper'

module Kanzashi
  class Plugin
    remove_const :PLUGINS_DIR
    PLUGINS_DIR = File.expand_path("#{File.dirname(__FILE__)}/plugins")
  end
end

describe Kanzashi::Plugin do
  describe ".list" do
    it "lists all plugin in plugins_dir" do
      Kanzashi::Plugin.list.size.should == 3
    end
  end

  describe ".plug" do
    it "loads specified plugin" do
      a = false
      Kanzashi::Hook.test_plugin_load_a { a = true }
      Kanzashi::Plugin.plug :a
      a.should be_true
    end
  end

  describe ".plug_all" do
    it "loads all enabled plugin in configuration" do
      a = []
      Kanzashi::Hook.test_plugin_load_b { a << true }

      Kanzashi::Config.load_config(<<-YAMMY_YAML)
plugins:
  a:
    enabled: false
  b:
    enabled: true
  c:
    enabled: true
      YAMMY_YAML

      Kanzashi::Plugin.plug_all

      a.size.should == 2
    end
  end
end

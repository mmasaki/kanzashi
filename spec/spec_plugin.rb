require_relative './helper'

module Kanzashi
  module Plugin
    remove_const :PLUGINS_DIR
    PLUGINS_DIR = File.expand_path("#{File.dirname(__FILE__)}/plugins_for_spec")
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
      Kanzashi::Plugin.plug :a
    end
  end

  describe ".plug_all" do
    it "loads all enabled plugin in configuration" do
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
    end
  end
end

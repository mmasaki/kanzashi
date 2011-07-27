require_relative './helper'

describe Kanzashi::Config do
  it "@@config is customhash" do
    Kanzashi::Config.class_variable_get(:"@@config").should be_a_kind_of(Kanzashi::Util::CustomHash)
  end

  describe ".load_config" do
    before do
      Kanzashi::Config.reset
    end

    it "overrides default config" do
      Kanzashi::Config.load_config("")
      Kanzashi::Config.config.should == Kanzashi::Config::DEFAULT

      Kanzashi::Config.load_config(<<-EOF)
      user:
        nick: hi
      server:
        bind: 127.0.0.1
      EOF
      Kanzashi::Config.config.should_not == Kanzashi::Config::DEFAULT
      Kanzashi::Config.config.user.nick.should == "hi"
      Kanzashi::Config.config.user.user.should == "kanzashi"
      Kanzashi::Config.config.server.port.should == 8082
      Kanzashi::Config.config.server.bind.should == "127.0.0.1"
    end

    it "saves old config" do
      Kanzashi::Config.load_config(<<-EOF)
      user:
        nick: hi
      server:
        bind: 127.0.0.1
      EOF
      Kanzashi::Config.class_variable_get(:"@@old_config").should == Kanzashi::Config::DEFAULT
    end

    it "can't modify config_file" do
      Kanzashi::Config.load_config(<<-EOF)
      config_file: shouldnt_be_hacked.yml
      EOF
      Kanzashi::Config.config.config_file.should == "config.yml"
    end
  end

  describe ".config" do
    before do
      Kanzashi::Config.reset
    end

    it "returns customhash" do
      Kanzashi::Config.load_config("")
      Kanzashi::Config.config.should be_a_kind_of(Kanzashi::Util::CustomHash)
    end
  end

  describe ".parse" do
    before do
      Kanzashi::Config.reset
    end

    it "-c option" do
      begin
        Kanzashi::Config.parse(["-c","configa.yml"])
      rescue Exception
      end
      Kanzashi::Config.config.config_file.should == "configa.yml"

    end
  end
end

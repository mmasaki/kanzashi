require_relative './helper'

describe Kanzashi::Config do
  it "@@config is customhash" do
    Kanzashi::Config.instance_eval { @@config }.should be_a_kind_of(Kanzashi::Util::CustomHash)
  end

  descibe ".load_config" do
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
      Kanzashi::Config.config.should != Kanzashi::Config::DEFAULT
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
      Kanzashi::Config.instance_eval { @@old_config }.should == Kanzashi::Config::DEFAULT
    end

    it "can't edit config_file" do
    end
  end

  describe ".config" do
    before do
      Kanzashi::Config.reset
    end

    it "returns customhash" do
    end
  end

  describe ".parse" do
    before do
      Kanzashi::Config.reset
    end

    it "-c option" do
    end
  end
end

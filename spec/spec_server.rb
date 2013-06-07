require 'timeout'
require_relative './helper'

class MocKanzashi
  include Kanzashi::Server

  attr_reader :datas

  def close_connection(a=false)
    call_hooks(:mock_close, a)
  end

  def send_data(data)
    @datas ||= []
    @datas << data
  end

  def line(l)
    receive_line(l+"\r\n")
  end

  def close_connection_after_writing
    call_hooks(:mock_close, true)
  end
end

describe Kanzashi::Server do
  before :all do
    TestIRCd.wait
    Kanzashi::Config.load_config <<-EOY
    networks:
      local:
        host: localhost
        port: #{TestIRCd.port}
        encoding: UTF-8
        join_to:
          - hola
          - "#tere"
    EOY
    a = false
    b = false
    Kanzashi::Server.plugin do
      on(:started) { a = true }
      on(:connect) { b = true }
    end
    th = Thread.new { EM.run { Kanzashi::Server.start_and_connect } }
    nil until a && b
  end

  th = nil
  before do
    Kanzashi::Config.reset

    Kanzashi::Config.load_config <<-EOY
    networks:
      local:
        host: localhost
        port: #{TestIRCd.port}
        encoding: UTF-8
        join_to:
          - hola
          - "#tere"
    EOY

    #th ||= Thread.new { Kanzashi::Server.start_and_connect }
    @server = MocKanzashi.new
  end
  
  it "says error when specified wrong password" do
    Kanzashi::Config.load_config <<-EOY
server:
  pass: hi
    EOY
    a = false
    Kanzashi::Server.plugin do
      on(:bad_password) { a = true }
    end
    @server.line "PASS hola"
    a.should be_true
  end

  it "requires password when password specified in config" do
    Kanzashi::Config.load_config <<-EOY
server:
  pass: hi
    EOY
    @server.line "PASS hi"
    @server.line "NICK kanzashi"
    @server.line "USER kanzashi kanzashi kanzashi"
    @server.datas.join.should match(/^:localhost 001/)
  end

  it "password also accepts in SHA256 sum" do
    Kanzashi::Config.load_config <<-EOY
server:
  pass: 8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4
    EOY
    @server.line "PASS hi"
    @server.line "NICK kanzashi"
    @server.line "USER kanzashi kanzashi kanzashi"
    @server.datas.join.should match(/^:localhost 001/)
  end

  it "doesn't require password when password is not specified in config" do
    Kanzashi::Config.load_config <<-EOY
server:
  pass: false
    EOY

    @server.line "NICK kanzashi"
    @server.line "USER kanzashi kanzashi kanzashi"
    @server.datas.join.should match(/^:localhost 001/)
  end

  it "pass messages to network" do
    a = nil
    Kanzashi::Server.plugin do
      on(:privmsg) {|m| a = m }
    end
    @server.line "NICK kanzashi"
    @server.line "USER kanzashi kanzashi kanzashi"
    @server.line "JOIN #hi@local"
    @server.line "PRIVMSG #hi@local :hi"
    timeout(3) {
      nil until a
    }
    a[1].should == "hi"
  end

  it "sends JOIN command when connected to networks" do # TODO: spec_client.rb
    TestIRCd.class_variable_get(:"@@channels").has_key?("#hola").should be_true
    TestIRCd.class_variable_get(:"@@channels").has_key?("#tere").should be_true
  end

  it "sends JOIN command to client when connected to kanzashi" do
    @server.line "NICK kanzashi"
    @server.line "USER kanzashi kanzashi kanzashi"
    @server.datas.join.should match(/#hola@local/)
    @server.datas.join.should match(/#tere@local/)
  end

  it "sends NICK commend when client specified nick is not equal to nick in config" do
    @server.line "NICK kanzashii"
    @server.line "USER kanzashi kanzashi kanzashi"
    @server.datas.join.should match(/^:kanzashii!kanzashi@localhost NICK kanzashi/)
  end

  it "sends RPL_WELCOME with prefix" do
    Kanzashi::Config.load_config <<-EOY
server:
  pass: hi
    EOY
    @server.line "PASS hi"
    @server.line "NICK kanzashi"
    @server.line "USER kanzashi kanzashi kanzashi"
    @server.datas.join.should match(/^:localhost 001 kanzashi :Welcome to the Internet Relay Network kanzashi!kanzashi@localhost/)
  end
end

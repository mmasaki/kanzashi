require 'timeout'
require_relative './helper'

trap(:INT) { exit }

CRLF = "\r\n"

describe Kanzashi::Server do
  before :all do
    @test_port = 1234
    @test_password = "hi"
    @start     = false
    @connected = false
    TestIRCd.wait
    Kanzashi::Config.load_config <<-EOY
server:
  bind: 127.0.0.1
  port: #{@test_port}
  pass: #{Digest::SHA256.hexdigest(@test_password)}
networks:
  local:
    host: localhost
    port: #{TestIRCd.port}
    encoding: UTF-8
    join_to:
      - hola
      - "#tere"
    EOY
    Kanzashi::Server.plugin do
      on(:start)   { @start     = true }
      on(:connect) { @connected = true }
    end
    th = Thread.new do
      EventMachine.run do
        Kanzashi::Server.start_and_connect
        EventMachine.start_server Kanzashi.config.server.bind, Kanzashi.config.server.port, Kanzashi::Server
      end
    end
    nil until th.stop?
    sleep 1
  end
  
  before do
    begin
      @socket = TCPSocket.new("localhost", @test_port)
    rescue Errno::ECONNREFUSED => ex
      sleep 1
      retry
    end
  end

  def send(str)
    str += CRLF unless str.end_with?(CRLF)
    @socket.write(str)
  end
  
  def recv
    line = @socket.gets
    line.chomp! if line
    line
  end

  context "password not specified" do
    before(:all) do
      Kanzashi::Config.load_config <<-EOY
server:
  pass: false
      EOY
    end

    it "doesn't require a password" do
      send "NICK kanzashi"
      send "USER kanzashi kanzashi kanzashi"
      recv.should == ":localhost 001 kanzashi :Welcome to the Internet Relay Network kanzashi!kanzashi@localhost"
    end

    after(:all) do
      Kanzashi::Config.load_config <<-EOY
server:
  pass: #{Digest::SHA256.hexdigest(@test_password)}
      EOY
    end 
  end

  context "password specified" do
    it "should be logged in with raw password" do
      send "PASS #{@test_password}"
      send "NICK kanzashi"
      send "USER kanzashi kanzashi kanzashi"
      recv.should == ":localhost 001 kanzashi :Welcome to the Internet Relay Network kanzashi!kanzashi@localhost"
    end
    
    it "should be logged in with sha256 digest" do
      send "PASS #{Digest::SHA256.hexdigest(@test_password)}"
      send "NICK kanzashi"
      send "USER kanzashi kanzashi kanzashi"
      recv.should == ":localhost 001 kanzashi :Welcome to the Internet Relay Network kanzashi!kanzashi@localhost"
    end
  end

  context "when specified wrong password" do
    before(:all) do
      $bad_password = false
      Kanzashi::Server.plugin do
        on(:bad_password) { $bad_password = true }
      end
    end

    before { send "PASS bad_password" }

    it "says error" do
      recv.should == "ERROR :Bad password?"
    end
  
    it "calls :bad_password hooks" do
      $bad_password.should be_true
    end
  end

  it "pass messages to network" do
    $privmsg = nil
    Kanzashi::Server.plugin do
      on(:privmsg) {|m| $privmsg = m }
    end
    send "PASS #{@test_password}"
    send "NICK kanzashi"
    send "USER kanzashi kanzashi kanzashi"
    send "JOIN #hi@local"
    send "PRIVMSG #hi@local :hi"
    timeout(3) do
      nil until $privmsg
    end
    $privmsg[1].should == "hi"
  end

  it "sends JOIN command to client when connected to kanzashi" do
    send "PASS #{@test_password}"
    send "NICK kanzashi"
    send "USER kanzashi kanzashi kanzashi"
    recv # drop welcome message
    recv.should == ":kanzashi!kanzashi@localhost JOIN #hi@local"
  end
  
  it "sends NICK commend when client specified nick is not equal to nick in config" do
    send "PASS #{@test_password}"
    send "NICK not_equal_to_nick_in_config"
    send "USER kanzashi kanzashi kanzashi"
    recv
    recv.should == ":not_equal_to_nick_in_config!kanzashi@localhost NICK kanzashi"
  end
end

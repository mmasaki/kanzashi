require 'eventmachine'
require 'net/irc'
require 'yaml'

module Kanzashi
  module Client
    def initialize(relay)
      @relay = relay
    end

    def receive_data(data)
      @relay.receive_from_server(data)
    end
  
    def send_data(data) # ここでSSL対応をする
      super
    end
  end

  module Server
    def initialize
      # ファイルから設定を読み出す
      @config ||= YAML.load(File.open(config_filename))
      connect_to_servers unless @servers
    end

    def connect_to_servers
      @servers = {}
      # サーバとコネクションを張る
      @config[:servers].each do |server_name, value|
        connection = EventMachine::connect(value[0], value[1], Kanzashi::Client, self)
        connection.send_data("NICK Kanzashi\r\nUSER Kanzashi 8 * :Kanzashi\r\n")
        @servers[server_name] = connection
      end
    end

    def receive_data(data)
      data.each_line do |line|
        p line
        m = Net::IRC::Message.parse(line)
        @auth = @config[:pass] == m[0] if  m.command ==  "PASS"
        close_connection unless @auth
        case m.command
        when "NICK"
        when "USER"
          send_data("001 #{m[0]} welcome to Riarra\r\n")
        when "JOIN"
          m[0].split(",").each do |channels|
            /(.+)@(.+)/ =~ channels
            channel_name = $1
            server = $2.to_sym
            @servers[server].send_data("JOIN #{channel_name}\r\n")
          end
        when "PRIVMSG" 
        when "QUIT"
          send_data("ERROR :Closing Link\r\n")
          close_connection
        end
      end
    end

    def receive_from_server(data)
      p data
    end
  end
end

EventMachine::run do
  EventMachine::start_server "0.0.0.0", 8082, Kanzashi::Server, "config.yml" 
end

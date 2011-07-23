# encoding: utf-8
require 'eventmachine'
require 'net/irc'
require 'yaml'

module Kanzashi
  DEBUG = true

  def debug_p(str)
    p str if DEBUG
  end

  module Client
    include Kanzashi
    @@relay = []

    def initialize(server_name)
      @server_name = server_name
    end

    def self.add_connection(c)
      @@relay << c
    end

    def channel_rewrite(params)
      params.each do |param|
        param.concat("@#{@server_name}") if param.include?("#")
      end
    end

    def receive_data(data)
      data.each_line("\r\n") do |line|
        if @fragment
          line = @fragment + line
          @fragment = nil
        end
        begin
          m = Net::IRC::Message.parse(line)
        rescue # 断片が送られて来てパースに失敗した時の処理
          @fragment = line
          break
        end
        case m.command
        when "PING"
          send_data "PONG Kanzashi\r\n"
        else
          line.encode!(Encoding::UTF_8, Encoding::ISO2022_JP, {:invalid => :replace})
          debug_p line
          params = line.split
          channel_rewrite(params)
          @@relay.each do |r|
            r.receive_from_server("#{params.join(" ")}\r\n")
          end
        end
      end
    end
  
    def send_data(data) # ここでSSL対応をする
      super
      debug_p self
    end
  end

  module Server
    include Kanzashi

    def initialize
      Client.add_connection(self)
    end

    def self.start_and_connect(config_filename)
      @@config = YAML.load(File.open(config_filename))
      @@servers = {}
      # サーバとコネクションを張る
      @@config[:servers].each do |server_name, value|
        connection = EventMachine::connect(value[0], value[1], Client, server_name)
        connection.send_data("NICK Kanzashi\r\nUSER Kanzashi 8 * :Kanzashi\r\n")
        @@servers[server_name] = connection
      end
    end

    def debug_p(str)
      p str if DEBUG
    end

    def receive_data(data)
      data.each_line("\r\n") do |line|
        m = Net::IRC::Message.parse(line)
        if  m.command ==  "PASS"
          @auth = @@config[:pass] == m[0]
          next
        end
        close_connection unless @auth
        case m.command
        when "NICK", "PASS"
        when "USER"
          send_data "001 #{m[0]} welcome to Kanzashi\r\n"
        when "QUIT"
          send_data "ERROR :Closing Link\r\n"
          close_connection
        else
          send_server(line)
        end
      end
    end

    # 適切なサーバに送信
    def send_server(line)
      params = line.split
      channels = nil
      channel_pos = params.each.find_index do |param|
        if param.include?("#")
          channels = param
          true
        else
          false
        end
      end
      if channels
        channels.split(",").each do |channel|
          /(.+)@(.+)/ =~ channel
          channel_name = $1
          server = $2.to_sym
          params[channel_pos].replace(channel_name)
          data = "#{params.join(" ")}\r\n"
          debug_p data
          @@servers[server].send_data(data.encode!(Encoding::ISO2022_JP, Encoding::UTF_8, {:invalid => :replace}))
        end
      end
    end

    def receive_from_server(data)
      send_data(data)
    end
  end
end

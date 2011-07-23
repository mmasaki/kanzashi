# encoding: utf-8
require 'eventmachine'
require 'net/irc'
require 'yaml'

module Kanzashi
  DEBUG = true

  # デバッグ用の出力
  def debug_p(str)
    p str if DEBUG
  end

  module Client # IRCクライアントとしてサーバとの通信をするモジュール
    include Kanzashi
    @@relay = [] # リレー先のコネクションの入った配列

    def initialize(server_name, encoding)
      @server_name = server_name
      @encoding = Encoding.find(encoding)
    end

    # 新しいクライアントからのコネクションを追加
    def self.add_connection(c)
      @@relay << c
    end

    # サーバからのレスポンスにチャンネル名が含まれていたら、サーバ名を付加して書き換える
    def channel_rewrite(params)
      params.each do |param|
        if /#|%|!/ =~ param
          channels = []
          param.split(",").each do |channel|
            channels << "#{channel}@#{@server_name}"
          end
          param.replace(channels.join(","))
        end
      end
    end
  
    # サーバから受信したデータの処理
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
          line.encode!(Encoding::UTF_8, @encoding, {:invalid => :replace})
          debug_p line
          params = line.split
          channel_rewrite(params)
          @@relay.each do |r|
            r.receive_from_server("#{params.join(" ")}\r\n")
          end
        end
      end
    end
  
    def send_data(data)
      debug_p self
      debug_p data
      data.encode!(@encoding, Encoding::UTF_8, {:invalid => :replace})
      super
    end
  end

  module Server # IRCクライアントに対してサーバとして振舞うモジュール
    include Kanzashi

    def initialize
      Client.add_connection(self)
    end

    def self.start_and_connect(config_filename)
      @@config = YAML.load(File.open(config_filename))
      @@servers = {}
      # サーバとコネクションを張る
      @@config[:servers].each do |server_name, value|
        connection = EventMachine::connect(value[0], value[1], Client, server_name, value[2])
        @@servers[server_name] = connection
        connection.send_data("NICK #{@@config[:nick]}\r\nUSER #{@@config[:nick]} 8 * :#{@@config[:realname]}\r\n")
      end
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
        when "NICK"
        when "USER"
          send_data "001 #{m[0]} welcome to Kanzashi.\r\n"
        when "QUIT"
          send_data "ERROR :Closing Link.\r\n"
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
        if /#|%|!/ =~ param
          channels = param
          true
        else
          false
        end
      end
      if channels
        channels.split(",").each do |channel|
          if /(.+)@(.+)/ =~ channel
            channel_name = $1
            server = @@servers[$2.to_sym]
          end
          unless server # サーバのコネクションの取得に失敗した場合
            channel_name = channel
            server = @@servers.first[1] # サーバリストの最初にあるサーバのコネクション
          end
          params[channel_pos].replace(channel_name)
          server.send_data("#{params.join(" ")}\r\n")
        end
      end
    end

    def receive_from_server(data)
      send_data(data)
    end
  end
end

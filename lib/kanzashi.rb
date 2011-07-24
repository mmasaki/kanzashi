# encoding: utf-8
require 'eventmachine'
require 'net/irc'
require 'yaml'
require 'digest/sha2'

module Kanzashi
  DEBUG = true

  # デバッグ用の出力
  def debug_p(str)
    p str if DEBUG
  end

  module Client # IRCクライアントとしてサーバとの通信をするモジュール
    include Kanzashi
    @@relay_to = [] # an array includes connections to relay

    def initialize(server_name, encoding, use_ssl=false)
      @server_name = server_name
      @encoding = Encoding.find(encoding)
      @channels = {}
      @buffer = BufferedTokenizer.new("\r\n")
      @use_ssl = use_ssl
    end

    def post_init
      start_tls if @use_ssl # enable SSL
    end

    # add new connection from client
    def self.add_connection(c)
      @@relay_to << c
    end

    # サーバからのレスポンスにチャンネル名が含まれていたら、サーバ名を付加して書き換える
    def channel_rewrite(line)
      params = line.split
      params.each do |param|
        if /#|%|!/ =~ param
          channels = []
          param.split(",").each do |channel|
            channels << "#{channel}@#{@server_name}"
          end
          param.replace(channels.join(","))
        end
      end
      params.join(" ").concat("\r\n")
    end

    def receive_line(line)
      m = Net::IRC::Message.parse(line)
      line.encode!(Encoding::UTF_8, @encoding, {:invalid => :replace})
      case m.command
      when "PING"
        send_data "PONG Kanzashi\r\n"
      when "JOIN"
        channel_sym = m[0].to_s.to_sym
        @channels[channel_sym] = [] unless @channels.keys.include?(channel_sym)
        relay(channel_rewrite(line))
      when "332", "333", "366"
        channel_sym = m[1].to_s.to_sym
        @channels[channel_sym] << channel_rewrite(line) if @channels[channel_sym]
        relay(channel_rewrite(line))
      when "353"
        channel_sym = m[2].to_s.to_sym
        @channels[channel_sym] << channel_rewrite(line) if @channels[channel_sym]
        relay(channel_rewrite(line))
      else
        debug_p line
        relay(channel_rewrite(line))
      end  
    end
  
    # サーバから受信したデータの処理
    def receive_data(data)
      @buffer.extract(data).each do |line|
        line.concat("\r\n")
        receive_line(line)
      end
    end

    def relay(data)
      @@relay_to.each { |r| r.receive_from_server(data) }
    end

    def join(channel_name)
      channel_sym = channel_name.to_sym
      if @channels.keys.include?(channel_sym)
        relay(":#{@@config[:nick]} JOIN :#{channel_name}@#{@server_name}\r\n")
        @channels[channel_sym].each do |line|
          relay(line)
        end
      else
        send_data("JOIN #{channel_name}\r\n")
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
      @buffer = BufferedTokenizer.new("\r\n")
    end

    def post_init
      start_tls(@@config[:ssl_opts] ? @@config[:ssl_opts] : {}) if @@config[:use_ssl] # enable SSL
    end

    def self.start_and_connect(config_filename)
      @@config = YAML.load(File.open(config_filename))
      @@servers = {}
      # サーバとコネクションを張る
      @@config[:servers].each do |server_name, value|
        connection = EventMachine::connect(value[0], value[1], Client, server_name, value[2], value[3])
        @@servers[server_name] = connection
        connection.send_data("NICK #{@@config[:nick]}\r\nUSER #{@@config[:nick]} 8 * :#{@@config[:realname]}\r\n")
      end
    end

    def receive_line(line)
      m = Net::IRC::Message.parse(line)
      if  m.command ==  "PASS"
        @auth = @@config[:pass] == Digest::SHA256.hexdigest(m[0].to_s)
      end
      close_connection unless @auth
      case m.command
      when "NICK", "PONG"
      when "USER"
        send_data "001 #{m[0]} welcome to Kanzashi.\r\n"
      when "JOIN"
        m[0].split(",").each do |channel|
          channel_name, server = split_channel_and_server(channel)
          server.join(channel_name)
        end
      when "QUIT"
        send_data "ERROR :Closing Link.\r\n"
        close_connection
      else
        send_server(line)
      end
    end

    def receive_data(data)
      @buffer.extract(data).each do |line|
        line.concat("\r\n")
        receive_line(line)
      end
    end

    def split_channel_and_server(channel)
      if /(.+)@(.+)/ =~ channel
        channel_name = $1
        server = @@servers[$2.to_sym]
      end
      unless server # サーバのコネクションの取得に失敗した場合
        channel_name = channel
        server = @@servers.first[1] # サーバリストの最初にあるサーバのコネクション
      end
      [channel_name, server]
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
          channel_name, server = split_channel_and_server(channel)
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

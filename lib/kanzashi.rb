# encoding: utf-8
require 'eventmachine'
require 'net/irc'
require 'yaml'
require 'optparse'
require 'digest/sha2'

module Kanzashi
  DEBUG = true # a flag to enable/disable debug print

  module Util
    class CustomHash < Hash
      class << self
        undef new
        def new(a)
          self[a]
        end
      end

      def self.[](a)
        h = (super a.to_a)
        h.keys.select{|key| key.kind_of?(String) }.each do |key|
          h[key.to_sym] = h.delete(key)
        end
        h.each do |key,value|
          case value
          when Array
            h[key] = CustomArray.new(value)
          when Hash
            h[key] = CustomHash.new(value)
          end
        end
        h
      end

      def method_missing(name,*args)
        self[name] || super
      end
    end

    class CustomArray < Array
      def initialize(*args)
        super *args
        self.map! do |x|
          if x.kind_of?(Hash) && x.class != CustomHash
            CustomHash.new(x)
          else; x; end
        end
      end
    end

  end

  module UtilMethod
    def config
      Config.config
    end
  end
  include UtilMethod
  class << self; include UtilMethod; end

  module Config
    include Kanzashi
    @@config = {
      config_file: "config.yml",
      user: {
        nick: "kanzashi",
        user: "kanzashi",
        real: "kanzashi that better tiarra"
      },
      server: {
        port: 8081,
        bind: "0.0.0.0",
        pass: nil,
        tls: false
      },
      networks: {}
    }
    @@old_config = nil
    @@config = Util::CustomHash.new(@@config)

    class << self
      def load_config
        @@old_config = @@config.dup
        yaml = Util::CustomHash.new(YAML.load(open(@@config[:config_file])))
        yaml.delete :config_file
        [:user,:server].each do |k|
          if (_ = yaml.delete(k))
            @@config[k].merge! _
          end
        end
        @@config.merge! yaml
        @@config = Util::CustomHash.new(@@config)
      end

      def config
        @@old_config ? @@config : load_config
      end

      def parse(argv)
        parser = OptionParser.new
        config_file = "config.yml"

        parser.on('-c FILE','--config=FILE','specify config file') do |file|
          @@config[:config_file] = file
        end

        parser.parse(argv)

        load_config
        self
      end
    end
  end

  # debug print
  # TODO: This should be replaced by Logger. (by sorah)
  def debug_p(str)
    p str if DEBUG
  end


  # a module to communicate with IRC servers as a client
  module Client
    include Kanzashi
    @@relay_to = [] # an array includes connections to relay

    def initialize(server_name, encoding, use_tls=false)
      @server_name = server_name
      @encoding = Encoding.find(encoding)
      @channels = {}
      @buffer = BufferedTokenizer.new("\r\n")
      @use_tls = use_tls
    end

    def post_init
      start_tls if @use_tls # enable TLS
    end

    # add new connection from clients
    def self.add_connection(connection)
      @@relay_to << connection
    end

    # rewrite channel names for Kanzashi clients
    def channel_rewrite(line)
      params = line.split
      params.each do |param|
        if /^:?(#|%|!)/ =~ param
          channels = []
          param.split(",").each do |channel|
            channels << "#{channel}@#{@server_name}"
          end
          param.replace(channels.join(","))
          break
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
        @channels[channel_sym] = [] unless @channels.has_key?(channel_sym)
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

    # process receiveed data
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
        relay(":#{config[:nick]} JOIN :#{channel_name}@#{@server_name}\r\n")
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

  # a module behaves like an IRC server to IRC clients.
  module Server
    include Kanzashi
    class << self; include UtilMethod; end

    def initialize
      Client.add_connection(self)
      @buffer = BufferedTokenizer.new("\r\n")
    end

    def post_init
      if config[:server][:tls] # enable TLS
        start_tls(config[:server][:tls].kind_of?(Hash) ? config[:server][:tls] : {})
      end
    end

    def self.start_and_connect
      @@servers = {}
      # connect to specified server
      config[:networks].each do |server_name, value|
        connection = EventMachine::connect(value[:host], value[:port], Client, server_name, value[:encoding], value[:tls])
        @@servers[server_name] = connection
        connection.send_data("NICK #{config[:user][:nick]}\r\nUSER #{config[:user][:user]||config[:user][:nick]} 8 * :#{config[:user][:real]}\r\n")
      end
    end

    def receive_line(line)
      m = Net::IRC::Message.parse(line)
      p m
      if  m.command ==  "PASS"
        p config[:server][:pass]
        p m[0].to_s
        @auth = (config[:server][:pass] == Digest::SHA256.hexdigest(m[0].to_s) || config[:server][:pass] == m[0].to_s)
        p @auth
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
      if /^:?((?:#|%|!).+)@(.+)/ =~ channel
        channel_name = $1
        server = @@servers[$2.to_sym]
      end
      unless server # in the case where the user specifies invaild server
        channel_name = channel
        server = @@servers.first[1] # the first connection of servers list
      end
      [channel_name, server]
    end

    # send data to specified server
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

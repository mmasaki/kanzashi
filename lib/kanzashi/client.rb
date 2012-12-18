module Kanzashi
  # a module to communicate with IRC servers as a client
  module Client
    include Kanzashi

    class << self
      include UtilMethod

      # add new connection from clients
      def add_connection(connection)
        @@relay_to << connection
      end

      def del_connection(connection)
        @@relay_to.delete(connection)
      end
    end

    @@relay_to = [] # an array includes connections to relay

    attr_reader :channels, :nick, :server_name

    def initialize(server_name, encoding, use_tls=false)
      @server_name = server_name.freeze
      @encoding = Encoding.find(encoding)
      @channels = {}
      @buffer = BufferedTokenizer.new(CRLF)
      @use_tls = use_tls
      @nick = config.user.nick
    end

    def client?; true; end
    def server?; false; end
    alias from_server? client?
    alias from_client? server?

    def inspect
      "#<Client:#{@server_name}>"
    end

    alias to_s inspect

    def post_init
      start_tls if @use_tls # enable TLS
    end

    # process received data
    def receive_data(data)
      @buffer.extract(data).each do |line|
        line.chomp! # some IRC servers send CR+CR+LF in message of the day
        line.concat(CRLF)
        line.encode!(Encoding::UTF_8, @encoding, EncodeOpt)
        receive_line(line)
      end
    end

    def send_data(data)
      data.force_encoding(Encoding::UTF_8)
      data.concat(CRLF) unless data.end_with?(CRLF)
      log.debug("Client #{@server_name}:send_data") { data.inspect }
      data.encode!(@encoding, EncodeOpt)
      super
    end

    def nick=(new_nick)
      log.debug("Client #{@server_name}:change_nick") { new_nick.inspect }
      send_data "NICK #{new_nick}"
    end

    def join(channel_with_host, channel_name)
      log.debug("Client #{@server_name}:join") { channel_name }
      channel_sym = channel_with_host.to_sym
      if @channels.has_key?(channel_sym) # cases that kanzashi already joined specifed channnel
        @channels[channel_sym][:cache].each_value do |messages|
          messages.each {|message| relay(message) }
        end # send cached message
      else # cases that kanzashi hasn't joined specifed channnel yet
        send_data "JOIN #{channel_name}"
      end
    end

    def part(channel_sym)
      @channels.delete(channel_sym)
    end

    private

    def relay(data)
      @@relay_to.each { |r| r.receive_from_server(data) }
    end

    def message_nick(m)
      /^(.+?)(!.+?)?(@.+?)?$/ =~ m.prefix
      $1.to_s
    end

    def _join(m, line)
      m_nick = message_nick(m)
      channel_sym = channel_rewrite(m[0], @server_name).to_sym
      if m_nick == @nick # join of myself
        @channels[channel_sym] = { :cache => {}, :names => [] } unless @channels.has_key?(channel_sym)
      else
        @channels[channel_sym][:names] << m_nick
        relay(message_rewrite(line))
      end
    end
    
    # rewrite channel names for Kanzashi clients
    def message_rewrite(line)
      begin
        params = line.split
      rescue ArgumentError => ex
        log.error("Client") { ex.message }
      end
      if channel_param = params.find {|param| /^:?(#|&)/ =~ param }
        channels = channel_param.split(",")
        channels.map! do |channel|
          channel_rewrite(channel, @server_name)
        end
        channel_param.replace(channels.join(","))
      end
      params.join(" ").concat(CRLF)
    end

    def invite(m, line)
      if K.config[:others][:join_when_invited]
        send_data "JOIN #{m[1]}"
      else
        log.debug("Client #{@server_name}:recv") { line.inspect }
        relay(message_rewrite(line))
      end
    end

    def _nick(m, line)
      @nick = m[0].to_s if m.prefix.nick == @nick
      relay(message_rewrite(line))
    end

    # 002: RPL_YOURHOST
    def your_host
      config.networks[@server_name].join_to.each do |channel| # join to channel specifed in config file
        unless channel.start_with?("#")
          # String#prepend is a feature since 1.9.3
          channel.prepend("#") rescue channel.replace("##{channel}")
        end
        join(channel)
        sleep 0.2 # to avoid excess flood
      end
      Kh.call(:client_welcome, self)
    end

    # 353: RPL_NAMREPLY
    def name_reply(m, line)
      # reply to names
      channel_pos = 2
      relay_with_cache(m, channel_pos, line)
      channel_sym = m[channel_pos].to_s.to_sym
      @channels[channel_sym][:names] = m[3].to_s.split # cache names list
    end

    # relay message with cache
    def relay_with_cache(m, channel_pos, line)
      channel_sym = channel_rewrite(m[channel_pos], @server_name).to_sym
      rewrited_message = message_rewrite(line)
      @channels[channel_sym][:cache][m.command.to_sym] ||= []
      @channels[channel_sym][:cache][m.command.to_sym] << rewrited_message
      relay(rewrited_message)
    end

    def other_messages(m, line)
      log.debug("Client #{@server_name}:recv") { line.inspect }
      m.params[1].force_encoding(Encoding::BINARY) if m.params[1]
      begin
        relay(message_rewrite(line)) unless m.ctcp?
      ensure
        m.params[1].force_encoding(Encoding::UTF_8) if m.params[1]
      end
    end

    def parse_line(line)
      line.force_encoding(Encoding::BINARY)
      m = Net::IRC::Message.parse(line)
      line.force_encoding(Encoding::UTF_8)
      m.params.each{|x| x.force_encoding(Encoding::UTF_8) }
      return m
    rescue Net::IRC::Message::InvalidMessage => ex
      log.error("Client:#{ex.class}") { ex.message.encode!(Encoding::UTF_8) }
      return nil
    end

    def call_hooks(m)
      command = m.command.downcase
      Hook.call(command.to_sym, m, self)
      Hook.call("#{command}_from_server".to_sym, m, self)
    end

    def receive_line(line)
      m = parse_line(line)
      return unless m
      call_hooks(m) 
      case m.command
      when "PING"
        send_data "PONG #{config.user.nick}" # reply to ping
      when "JOIN"
        _join(m, line)
      when "INVITE"
        invite(m, line)
      when "NICK"
        _nick(m, line)
      when "002" # RPL_YOURHOST
        your_host
      when "332", # RPL_TOPIC
           "333", # RPL_TOPICWHOTIME
           "366"  # RPL_ENDOFNAME
        channel_pos = 1
        relay_with_cache(m, channel_pos, line)
      when "353"  # RPL_NAMREPLY
        name_reply(m, line)
      else # all other messages
        other_messages(m, line)
      end
    rescue => ex
      log.error("Client:#{ex.class}") { ex.message + ex.backtrace[0, 2].join(", ") }
    end
  end
end

module Kanzashi
  # a module behaves like an IRC server to IRC clients.
  module Server
    include Kanzashi

    class << self
      include UtilMethod

      # return the count of connections from IRC clients
      def client_count; @@client_count; end
      def networks; @@networks; end

      # send data to all IRC servers
      def send_to_all(data)
        @@networks.each_value do |server|
          server.send_data(data)
        end
      end

      def start_and_connect
        Plugin.plug_all

        Hook.call(:start)
        log.info("Server:start") { "Kanzashi starting..." }

        @@networks = {}
        config.networks.each do |server_name, server|
          log.info("Server:connect") { "Connecting to #{server_name}..."  }
          Hook.call(:connect, server_name)
          log.debug("Server:connect") { "#{server_name}: #{server}" }

          connection = EventMachine.connect(server.host, server.port, Client, server_name, server.encoding||"UTF-8", server.tls)
          @@networks[server_name] = connection

          connection.send_data "NICK #{config.user.nick}\r\nUSER #{config.user.user||config.user.nick} 8 * :#{config.user.real}"

          Hook.call(:connected, server_name)
          log.info("Server:connect") { "Connected to #{server_name}." }
        end

        log.info("Server:start") { "Kanzashi started." }
        Hook.call(:started)
        Hook.call(:detached, nil)
      end
    end

    @@client_count = 0

    attr_reader :user

    def initialize
      Client.add_connection(self)
      Hook.call(:new_connection, self)
      @buffer = BufferedTokenizer.new(CRLF)
      @user = {}
      @@client_count += 1
    end

    def client?; false; end
    def server?; true; end
    alias from_server? client?
    alias from_client? server?

    def post_init
      if config.server.tls # enable TLS
        start_tls(config.server.tls.kind_of?(Hash) ? config.server.tls : {})
      end
    end

    def send_data(data)
      log.debug("Server:send_data") { data.inspect }
      data.concat(CRLF) unless data.end_with?(CRLF)
      super
    end

    def receive_data(data)
      data.force_encoding(Encoding::UTF_8)
      @buffer.extract(data).each do |line|
        line.concat(CRLF)
        receive_line(line)
      end
    end

    # if detached, call Hook.detached.
    def unbind
      Client.del_connection(self)
      @@client_count -= 1
      Hook.call(:unbind, self)
      Hook.call(:detached, self) if @@client_count.zero?
    end

    alias receive_from_server send_data

    private

    def pass(m)
      if config.server.pass
        pass = m[0].to_s
        hexdigest = Digest::SHA256.hexdigest(pass)
        case config.server.pass
        when hexdigest, pass
          @auth = true
        end
      else # the case where the user has not specified password
        @auth = true
      end
      nil
    end

    def bad_password
      Hook.call(:bad_password, self)
      send_data "ERROR :Bad password?"
      close_connection_after_writing
    end

    def _user(m)
      Hook.call(:new_session, self)
      Hook.call(:attached) if @@client_count == 1

      @user[:username] = m[0].to_s
      @user[:realname] = m[3].to_s
      @user[:prefix] = "#{@user[:nick]}!#{@user[:username]}@localhost"

      send_data ":localhost 001 #{@user[:nick]} :Welcome to the Internet Relay Network #{@user[:prefix]}"

      unless @user[:nick] == config.user.nick
        send_data ":#{@user[:prefix]} NICK #{config.user.nick}"
        @user[:nick] = config.user.nick
        @user[:prefix] = "#{@user[:nick]}!#{@user[:username]}@localhost"
      end

      @@networks.each do |name,client|
        client.channels.each do |channel,v|
          send_data ":#{@user[:prefix]} JOIN #{channel}#{config.separator}#{name}"
          v[:cache].each {|k,l| send_data(l.chomp)}
        end
      end
    end

    def _join(m)
      channels = m[0].split(",")
      channels.each do |channel|
        send_data ":#{@user[:prefix]} JOIN #{channel}"
        channel_name, server = split_channel_and_server(channel)
        server.join(channel_name)
      end
    end

    def quit
      Hook.call(:quit, self)
      send_data "ERROR :Closing Link."
      close_connection_after_writing
    end

    def parse_line(line)
      line.force_encoding(Encoding::BINARY)
      m = Net::IRC::Message.parse(line)
      line.force_encoding(Encoding::UTF_8)
      m.params.each{|x| x.force_encoding(Encoding::UTF_8) }
      return m
    rescue Net::IRC::Message::InvalidMessage => ex
      log.error("Server:#{ex.class}") { ex.message }
      return nil
    end

    def call_hooks(m)
      command = m.command.downcase
      Hook.call(command.to_sym, m, self)
      Hook.call("#{command}_from_client".to_sym, m, self)
    end

    def receive_line(line)
      m = parse_line(line)
      return unless m
      log.debug("Server:receive_line") { "Received line: #{line.chomp.inspect}" }
      Hook.call(:receive_line, m,line.chomp)
      bad_password unless @auth || m.command == "PASS"
      case m.command
      when "PASS"
        pass(m)
      when "NICK"
        @@networks.each_value {|n| n.nick = m[0].to_s } if @user[:nick]
        @user[:nick] = m[0].to_s
      when "PONG"
        # do nothing
      when "USER"
        _user(m)
      when "JOIN"
        _join(m)
      when "QUIT"
        quit
      else
        send_server(line)
      end
      call_hooks(m)
    end

    # find channel param pos
    def find_channel_pos(params)
      params.each_with_index do |param, pos|
        return [param, pos] if /#|%|!/ =~ param
      end
      false
    end

    # send data to specified IRC server
    def send_server(line)
      params = line.split
      channels, channel_pos = find_channel_pos(params)
      if channels
        channels.split(",").each do |channel_with_host|
          channel_name, server = split_channel_and_server(channel_with_host)
          params[channel_pos].replace(channel_name)
          server.send_data(params.join(" "))
        end
      end
    end

    def split_channel_and_server(channel)
      if /^:?((?:#|!).+)#{Regexp.escape(config.separator)}(.+?)(:.+)?$/ =~ channel
        channel_name = $1
        channel_name.concat($3.to_s) if $3
        server = @@networks[$2.to_sym]
      end
      unless server # in cases where the user specifies invaild server
        channel_name = channel
        server = @@networks.first[1] # the first connection of servers list
      end
      [channel_name, server]
    end
  end
end

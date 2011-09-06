module Kanzashi
  # a module behaves like an IRC server to IRC clients.
  module Server
    include Kanzashi
    class << self; include UtilMethod; end
    @@client_count = 0

    def self.networks; @@networks; end

    attr_reader :user

    # return the count of connections from IRC clients
    def self.client_count 
      @@client_count
    end

    # send data to all IRC servers
    def self.send_to_all(data)
      @@networks.each_value do |server|
        server.send_data(data)
      end
    end

    def initialize
      Client.add_connection(self)
      Hook.call(:new_connection,self)
      @buffer = BufferedTokenizer.new("\r\n")
      @user = {}
      @@client_count += 1
    end

    def client?
      false
    end

    def server?
      true
    end

    alias from_server? client?
    alias from_client? server?

    def post_init
      if config.server.tls # enable TLS
        start_tls(config.server.tls.kind_of?(Hash) ? config.server.tls : {})
      end
    end

    def self.start_and_connect
      Plugin.plug_all

      Hook.call(:start)
      log.info("Server:start") {"Kanzashi starting..."}

      @@networks = {}
      config.networks.each do |server_name, server|
        log.info("Server:connect") {"Connecting to #{server_name}..."}
        Hook.call(:connect, server_name)
        log.debug("Server:connect") {"#{server_name}: #{server}"}

        connection = EventMachine.connect(server.host, server.port, Client, server_name, server.encoding||"UTF-8", server.tls)
        @@networks[server_name] = connection

        connection.send_data "NICK #{config.user.nick}\r\nUSER #{config.user.user||config.user.nick} 8 * :#{config.user.real}\r\n"

        Hook.call(:connected, server_name)
        log.info("Server:connect") {"Connected to #{server_name}."}
      end

      log.info("Server:start") {"Kanzashi started."}
      Hook.call(:started)
      Hook.call(:detached, nil)
    end

    def receive_line(line)
      m = Net::IRC::Message.parse(line)
      log.debug("Server:receive_line") {"Received line: #{line.chomp.inspect}"}
      Hook.call(:receive_line, m,line.chomp)
      if config.server.pass && m.command == "PASS" # authenticate
        @auth = (config.server.pass == Digest::SHA256.hexdigest(m[0].to_s) \
              || config.server.pass == m[0].to_s)
      else # the case where the user has not specified password
        @auth = true
      end
      unless @auth # Without authentication, it is needed to refuse all message except PASS
        Hook.call(:bad_password, self)
        send_data "ERROR :Bad password?\r\n"
        close_connection_after_writing
      end
      case m.command
      when "NICK"
        @@networks.each_value {|n| n.nick = m[0].to_s } if @user[:nick]
        @user[:nick] = m[0].to_s
      when "PONG"
        # do nothing
      when "USER"
        Hook.call(:new_session, self)
        Hook.call(:attached) if @@client_count == 1

        @user[:username] = m[0].to_s
        @user[:realname] = m[3].to_s
        @user[:prefix] = "#{@user[:nick]}!#{@user[:username]}@localhost"

        send_data ":localhost 001 #{@user[:nick]} :Welcome to the Internet Relay Network #{@user[:prefix]}\r\n"

        unless @user[:nick] == config.user.nick
          send_data ":#{@user[:prefix]} NICK #{config.user.nick}\r\n"
          @user[:nick] = config.user.nick
          @user[:prefix] = "#{@user[:nick]}!#{@user[:username]}@localhost"
        end

        @@networks.each do |name,client|
          client.channels.each do |channel,v|
            send_data ":#{@user[:prefix]} JOIN #{channel}#{config.separator}#{name}\r\n"
            v[:cache].each {|k,l| send_data(l.chomp << "\r\n")}
          end
        end
      when "JOIN"
        channels = m[0].split(",")
        channels.each do |channel|
          send_data ":#{@user[:prefix]} JOIN #{channel}\r\n" # in this case, i couldn't join channels with LimeChat
#          send_data ":#{@user[:username]} JOIN #{channel}\r\n"
          channel_name, server = split_channel_and_server(channel)
          server.join(channel_name)
        end
      when "QUIT"
        Hook.call(:quit, self)
        send_data "ERROR :Closing Link.\r\n"
        close_connection_after_writing
      else
        send_server(line)
      end
      Hook.call(m.command.downcase.to_sym, m, self)
      Hook.call((m.command.downcase + "_from_client").to_sym, m, self)
    end

    def send_data(data)
      log.debug("Server:send_data"){data.inspect}
      super data
    end

    def receive_data(data)
      @buffer.extract(data).each do |line|
        line.concat("\r\n")
        receive_line(line)
      end
    end

    def split_channel_and_server(channel)
      if /^:?((?:#|%|!).+)#{Regexp.escape(config.separator)}(.+)/ =~ channel
        channel_name = $1
        server = @@networks[$2.to_sym]
      end
      unless server # in cases where the user specifies invaild server
        channel_name = channel
        server = @@networks.first[1] # the first connection of servers list
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

    # if detached, call Hook.detached.
    def unbind
      @@client_count -= 1
      Hook.call(:unbind, self)
      Hook.call(:detached, self) if @@client_count.zero?
    end

    def receive_from_server(data)
      send_data(data)
    end
  end
end

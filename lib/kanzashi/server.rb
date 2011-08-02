module Kanzashi
  # a module behaves like an IRC server to IRC clients.
  module Server
    include Kanzashi
    class << self; include UtilMethod; end

    def initialize
      Client.add_connection(self)
      Hook.call(:new_connection,self)
      @buffer = BufferedTokenizer.new("\r\n")
      @user = {}
    end

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

        connection.send_data "NICK #{config.user.nick}\r\n"
        connection.send_data "USER #{config.user.user||config.user.nick} 8 * :#{config.user.real}\r\n"

        Hook.call(:connected, server_name)
        log.info("Server:connect") {"Connected to #{server_name}."}
      end

      log.info("Server:start") {"Kanzashi started."}
      Hook.call(:started)
    end

    def receive_line(line)
      m = Net::IRC::Message.parse(line)
      log.debug("Server:receive_line") {"Received line: #{line.chomp.inspect}"}
      Hook.call(:receive_line, m,line.chomp)
      if config.server.pass
        if m.command == "PASS" # authenticate
          @auth = (config.server.pass == Digest::SHA256.hexdigest(m[0].to_s) \
                || config.server.pass == m[0].to_s)
        end
      else # the case where the user has not specified password
        @auth = true
      end
      unless @auth # Without authentication, it is needed to refuse all message except PASS
        Hook.call(:bad_password,self)
        send_data "ERROR :Bad password?\r\n"
        close_connection(true) # close after writing
      end
      Hook.call(m.command.downcase.to_sym, m)
      case m.command
      when "NICK"
        @user[:nick] == m[0].to_s
      when "PONG"
        # do nothing
      when "USER"
        Hook.call(:new_session,self)
        send_data "001 #{m[0]} welcome to Kanzashi.\r\n"
        @user[:username] = m[0].to_s
        @user[:realname] = m[3].to_s
      when "JOIN"
        channels = m[0].split(",")
        channels.each do |channel|
          send_data ":#{@user[:username]} JOIN #{channel}\r\n"
          channel_name, server = split_channel_and_server(channel)
          server.join(channel_name)
        end
      when "QUIT"
        Hook.call(:quit,self)
        send_data "ERROR :Closing Link.\r\n"
        close_connection(true) # close after writing
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

    def receive_from_server(data)
      send_data(data)
    end
  end
end

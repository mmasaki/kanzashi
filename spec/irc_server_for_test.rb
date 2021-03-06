# irc_server_for_test.rb
# From: https://github.com/cho45/net-irc/blob/master/examples/ircd.rb
# Author: cho45 <cho45@lowreal.net>
# License: Ruby's

require 'net/irc'
require 'stringio'

class TestIRCd < Net::IRC::Server::Session
  @@instance = nil
  @@waited = false

  def self.instance; @@instance; end

  def self.port; @@instance ? @@instance.instance_eval{@serv.addr}[1] : nil; end

  def self.go
    @@instance = Net::IRC::Server.new(
      "127.0.0.1", 0, self,
      {logger: Logger.new(StringIO.new("","w"))})
    @@instance.start
    @@waited = false
  end

  def self.wait
     return if @@waited
     nil until ["run","sleep"].include?(@@instance.instance_eval{@accept ? @accept.status : nil})
     @@waited = true
  end

  def server_name
    "net-irc"
  end

  def server_version
    "0.0.0"
  end

  def available_user_modes
    "iosw"
  end

  def default_user_modes
    ""
  end

  def available_channel_modes
    "om"
  end

  def default_channel_modes
    ""
  end

  def initialize(*args)
    super
    @@channels ||= {}
    @@users    ||= {}
    @ping        = false
  end

  def on_pass(m)
  end

  def on_user(m)
    @user, @real = m.params[0], m.params[3]
    @host        = @socket.peeraddr[2]
    @prefix      = Prefix.new("#{@nick}!#{@user}@#{@host}")
    @joined_on   = @updated_on = Time.now.to_i

    post @socket, @prefix, NICK, nick
    @nick = nick
    @prefix = "#{@nick}!#{@user}@#{@host}"

    time = Time.now.to_i
    @@users[@nick.downcase] = {
      :nick       => @nick,
      :user       => @user,
      :host       => @host,
      :real       => @real,
      :prefix     => @prefix,
      :socket     => @socket,
      :joined_on  => time,
      :updated_on => time
    }

    initial_message

    start_ping
  end

  def on_join(m)
    channels = m.params[0].split(/\s*,\s*/)
    password = m.params[1]

    channels.each do |channel|
      unless channel.downcase =~ /^#/
        post @socket, server_name, ERR_NOSUCHCHANNEL, @nick, channel, "No such channel"
        next
      end

      unless @@channels.key?(channel.downcase)
        channel_create(channel)
      else
        return if @@channels[channel.downcase][:users].key?(@nick.downcase)

        @@channels[channel.downcase][:users][@nick.downcase] = []
      end

      mode = @@channels[channel.downcase][:mode].empty? ? "" : "+" + @@channels[channel.downcase][:mode]
      post @socket, server_name, RPL_CHANNELMODEIS, @nick, @@channels[channel.downcase][:alias], mode

      channel_users = ""
      @@channels[channel.downcase][:users].each do |nick, m|
        post @@users[nick][:socket], @prefix, JOIN, @@channels[channel.downcase][:alias]

        case
        when m.index("@")
          f = "@"
        when m.index("+")
          f = "+"
        else
          f = ""
        end
        channel_users += "#{f}#{@@users[nick.downcase][:nick]} "
      end
      post @socket, server_name, RPL_NAMREPLY, @@users[nick][:nick], "=", @@channels[channel.downcase][:alias], "#{channel_users.strip}"
      post @socket, server_name, RPL_ENDOFNAMES, @@users[nick][:nick], @@channels[channel.downcase][:alias], "End of /NAMES list"
    end
  end

  def on_part(m)
    channel, message = *m.params

    @@channels[channel.downcase][:users].each do |nick, f|
      post @@users[nick][:socket], @prefix, PART, @@channels[channel.downcase][:alias], message
    end
    channel_part(channel)
  end

  def on_quit(m)
    message = m.params[0]
    @@channels.each do |channel, f|
      if f[:users].key?(@nick.downcase)
        channel_part(channel)
        f[:users].each do |nick, m|
          post @@users[nick][:socket], @prefix, QUIT, message
        end
      end
    end
    finish
  end

  def on_disconnected
    super
    @@channels.each do |channel, f|
      if f[:users].key?(@nick.downcase)
        channel_part(channel)
        f[:users].each do |nick, m|
          post @@users[nick][:socket], @prefix, QUIT, "disconnect"
        end
      end
    end
    channel_part_all
    @@users.delete(@nick.downcase)
  end

  def on_who(m)
    channel = m.params[0]
    return unless channel

    c = channel.downcase
    case
    when @@channels.key?(c)
      @@channels[c][:users].each do |nickname, m|
        nick = @@users[nickname][:nick]
        user = @@users[nickname][:user]
        host = @@users[nickname][:host]
        real = @@users[nickname][:real]
        case
        when m.index("@")
          f = "@"
        when m.index("+")
          f = "+"
        else
          f = ""
        end
        post @socket, server_name, RPL_WHOREPLY, @nick, @@channels[c][:alias], user, host, server_name, nick, "H#{f}", "0 #{real}"
      end
      post @socket, server_name, RPL_ENDOFWHO, @nick, @@channels[c][:alias], "End of /WHO list"
    end
  end

  def on_mode(m)
  end

  def on_privmsg(m)
    Kh.call(:server_privmsg, m)

    while (Time.now.to_i - @updated_on < 2)
      sleep 2
    end
    idle_update

    return on_ctcp(m[0], ctcp_decoding(m[1])) if m.ctcp?

    target, message = *m.params
    t = target.downcase

    case
    when @@channels.key?(t)
      if @@channels[t][:users].key?(@nick.downcase)
        @@channels[t][:users].each do |nick, m|
          post @@users[nick][:socket], @prefix, PRIVMSG, @@channels[t][:alias], message unless nick == @nick.downcase
        end
      else
        post @socket, nil, ERR_CANNOTSENDTOCHAN, @nick, target, "Cannot send to channel"
      end
    when @@users.key?(t)
      post @@users[nick][:socket], @prefix, PRIVMSG, @@users[t][:nick], message
    else
      post @socket, nil, ERR_NOSUCHNICK, @nick, target, "No such nick/channel"
    end
  end

  def on_ping(m)
    post @socket, server_name, PONG, m.params[0]
  end

  def on_pong(m)
    @ping = true
  end

  def idle_update
    @updated_on = Time.now.to_i
    if logged_in?
      @@users[@nick.downcase][:updated_on] = @updated_on
    end
  end

  def channel_create(channel)
    @@channels[channel.downcase] = {
      :alias      => channel,
      :topic      => "",
      :mode       => default_channel_modes,
      :users      => {@nick.downcase => ["@"]},
    }
  end

  def channel_part(channel)
    @@channels[channel.downcase][:users].delete(@nick.downcase)
    channel_delete(channel.downcase) if @@channels[channel.downcase][:users].size == 0
  end

  def channel_part_all
    @@channels.each do |c|
      channel_part(c)
    end
  end

  def channel_delete(channel)
    @@channels.delete(channel.downcase)
  end

  def post(socket, prefix, command, *params)
    m = Message.new(prefix, command, params.map{|s|
      s.gsub(/[\r\n]/, "")
    })
    socket << m
  rescue
    finish
  end

  def start_ping
    Thread.start do
      loop do
        @ping = false
        time = Time.now.to_i
        if @ping == false && (time - @updated_on > 60)
          post @socket, server_name, PING, @prefix
          loop do
            sleep 1
            if @ping
              break
            end
            if 60 < Time.now.to_i - time
              Thread.stop
              finish
            end
          end
        end
        sleep 60
      end
    end
  end

  # Call when client connected.
  # Send RPL_WELCOME sequence. If you want to customize, override this method at subclass.
  def initial_message
    Kh.call(:server_connect)
    post @socket, server_name, RPL_WELCOME,  @nick, "Welcome to the Internet Relay Network #{@prefix}"
    post @socket, server_name, RPL_YOURHOST, @nick, "Your host is #{server_name}, running version #{server_version}"
    post @socket, server_name, RPL_CREATED,  @nick, "This server was created #{Time.now}"
    post @socket, server_name, RPL_MYINFO,   @nick, "#{server_name} #{server_version} #{available_user_modes} #{available_channel_modes}"
  end

end




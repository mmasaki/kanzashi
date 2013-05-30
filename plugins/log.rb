#encoding: utf-8
require "date"

module Kanzashi
  module Plugin
    class Log
      extend Kanzashi::UtilMethod

      def initialize
        config = K.c
        @directory = config[:directory] || "log"
        @header = config[:header] || "%T"
        @filename = config[:filename] || "%Y.%m.%d.txt" 
        @mode = config[:mode] || 0600
        @dir_mode = config[:dir_mode] || 0700
        @keep_file_open = config[:keep_file_open]
        @logfiles = {} if @keep_file_open
        @command = config[:command].split(",").map!{|x| x.to_sym } if config[:command]
        @distinguish_myself = @distinguish_myself.nil? || config[:distinguish_myself]
        @channel = Regexp.new(config[:channel]) if config[:channel]

        Dir.mkdir(@directory, @dir_mode) unless File.directory?(@directory)
      end  

      attr_reader :keep_file_open, :distinguish_myself

      def path(dst)
        "#{@directory}/#{dst}/#{Date.today.strftime(@filename)}"
      end

      def rotate(dst)
        dst = dst.to_sym
        if path(dst) != @logfiles[dst].path
          @logfiles[dst].close
          @logfiles[dst] = File.open(path(dst), "a", @mode)
        end
      end

      def puts(str, dst)
        if !@channel || @channel =~ dst
          str.replace("#{Time.now.strftime(@header)} #{str}")
          STDOUT.puts(str)
          if @keep_file_open
            rotate(dst)
            @logfiles[dst.to_sym].puts(str)
          else
            File.open(path(dst), "a", @mode) { |f| f.puts(str) }
          end
        end
      end

      def file_open(dst)
        dir = "#{@directory}/#{dst}"
        Dir.mkdir(dir, @dir_mode) unless File.directory?(dir)
        File.open(path(dst), "a", @mode)
      end

      def add_dst(channel_name)
        key = channel_name.to_sym
        @logfiles[key] = file_open(channel_name) unless @logfiles.has_key?(key)
      end

      # whether or not to record
      def record?(command)
        !@command || @command.include?(command)
      end
    end
  end
end

log_plugin_class = Kanzashi::Plugin::Log
log_plugin = nil

Kanzashi::Server.plugin do
  on :start do
    log_plugin = log_plugin_class.new
  end

  on :join do |m|
    m[0].to_s.split(",").each {|c| log_plugin.add_dst(c) }if log_plugin.keep_file_open
  end

  on :privmsg do |m, server|
    if log_plugin.record?(:privmsg) && !m.ctcp?
      log_plugin.puts(">#{m[0]}:#{server.user[:nick]}< #{m[1]}", m[0])
    end
  end

  on :notice do |m, server|
    if log_plugin.record?(:notice) && !m.ctcp?
      channel_name = m[0].to_s
      log_plugin.puts(")#{channel_name}:#{server.user[:nick]}( #{m[1]}", channel_name)
    end
  end
end

Kanzashi::Client.plugin do
  on :join do |m, client|
    nick = m.prefix.nick
    channel_name = log_plugin_class.channel_rewrite(m[0], client.server_name)
    if nick == client.nick # Kanzashi's join
      log_plugin.add_dst(channel_name) if log_plugin.keep_file_open
    elsif log_plugin.record?(:join) # others join
      log_plugin.puts("+ #{nick} (#{m.prefix}) to #{channel_name}", channel_name)
    end
  end

  on :part do |m, client|
    if log_plugin.record?(:part)
      channel_name = log_plugin_class.channel_rewrite(m[0], client.server_name)
      log_plugin.puts("- #{m.prefix.nick} (\"#{m[1]}\")", channel_name)
    end
  end

=begin
  on :quit do |m, client|
    if log_plugin.record?(:quit)
      #XXX: quit message has no channel name
      log_plugin.puts("! #{m.prefix.nick} (\"#{m[1]}\")", channel_name)
    end
  end
=end

  on :kick do |m, client|
    if log_plugin.record?(:kick)
      channel_name = log_plugin_class.channel_rewrite(m[0], client.server_name)
      log_plugin.puts("- #{m[1]} by #{m.prefix.nick} from #{channel_name} (#{m[2]})", channel_name)
    end
  end

  on :mode do |m, client|
    if log_plugin.record?(:mode) && /^(#|&).+$/ =~ m[0] # to avoid usermode MODE messages
      channel_name = log_plugin_class.channel_rewrite(m[0], client.server_name)
      log_plugin.puts("Mode by #{m.prefix.nick}: #{m[0]} #{m[1]} #{m[2]}", channel_name)
    end
  end

  on :privmsg do |m, client|
    if log_plugin.record?(:privmsg) && !m.ctcp?
      channel_name = log_plugin_class.channel_rewrite(m[0], client.server_name)
      if log_plugin.distinguish_myself
        log_plugin.puts(">#{m[0]}:#{m.prefix.nick}< #{m[1]}", channel_name)
      else
        log_plugin.puts("<#{m[0]}:#{m.prefix.nick}> #{m[1]}", channel_name)
      end
    end
  end

  on :notice do |m, client|
    if log_plugin.record?(:notice) && !m.ctcp?
      channel_name = m[0].to_s
      if channel_name != "*" && channel_name != client.nick
        channel_name = log_plugin_class.channel_rewrite(channel_name, client.server_name)
        if log_plugin.distinguish_myself
          log_plugin.puts(")#{channel_name}:#{m.prefix.nick}(#{m[1]}", channel_name)
        else
          log_plugin.puts("(#{channel_name}:#{m.prefix.nick})#{m[1]}", channel_name)
        end
      end
    end
  end

  on :nick do |m, client|
    if log_plugin.record?(:nick)
      nick = m.prefix.nick
      client.channels.each do |channel, value|
        log_plugin.puts("#{nick} -> #{m[0]}", channel) if value[:names].include?(nick)
      end
    end
  end

  on :invite do |m, client|
    if log_plugin.record?(:invite)
      channel_name = log_plugin_class.channel_rewrite(m[1], client.server_name)
      log_plugin.puts("Invited by #{m[0]}: #{channel_name}", channel_name) 
    end
  end

  on :topic do |m, client|
    if log_plugin.record?(:topic)
      channel_name = log_plugin_class.channel_rewrite(m[0], client.server_name)
      log_plugin.puts("Topic of channel #{channel_name} by #{m.prefix.nick}: #{m[1]}", channel_name)
    end
  end
end

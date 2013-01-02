#encoding: utf-8
require "date"

class Kanzashi::Plugin::Log
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
      @logfiles[dst] = File.open(path(dst), "a", @mode) { |f| f.puts(str) }
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

log = Kanzashi::Plugin::Log.new

Kanzashi.plugin do
  from :Server do
    on :start do
      log = Kanzashi::Plugin::Log.new
    end

    on :join do |m|
      m[0].to_s.split(",").each {|c| log.add_dst(c) }if log.keep_file_open
    end

    on :privmsg do |m, server|
      if log.record?(:privmsg) && !m.ctcp?
        log.puts(">#{m[0]}:#{server.user[:nick]}< #{m[1]}", m[0])
      end
    end

    on :notice do |m, server|
      if log.record?(:notice) && !m.ctcp?
        channel_name = m[0].to_s
        log.puts(")#{channel_name}:#{server.user[:nick]}( #{m[1]}", channel_name)
      end
    end
  end

  from :Client do
    on :join do |m, client|
      nick = m.prefix.nick
      channel_name = Kh.channel_rewrite(m[0], client.server_name)
      if nick == client.nick # Kanzashi's join
        log.add_dst(channel_name) if log.keep_file_open
      elsif log.record?(:join) # others join
        log.puts("+ #{nick} (#{m.prefix}) to #{channel_name}", channel_name)
      end
    end

    on :part do |m, client|
      if log.record?(:part)
        channel_name = Kh.channel_rewrite(m[0], client.server_name)
        log.puts("- #{m.prefix.nick} (\"#{m[1]}\")", channel_name)
      end
    end

    on :quit do |m, client|
      if log.record?(:quit)
        channel_name = Kh.channel_rewrite(m[0], client.server_name)
        log.puts("! #{m.prefix.nick} (\"#{m[1]}\")", channel_name)
      end
    end

    on :kick do |m, client|
      if log.record?(:kick)
        channel_name = Kh.channel_rewrite(m[0], client.server_name)
        log.puts("- #{m[1]} by #{m.prefix.nick} from #{channel_name} (#{m[2]})", channel_name)
      end
    end

    on :mode do |m, client|
      if log.record?(:mode) && /^(#|&).+$/ =~ m[0] # to avoid usermode MODE messages
        channel_name = Kh.channel_rewrite(m[0], client.server_name)
        log.puts("Mode by #{m.prefix.nick}: #{m[0]} #{m[1]} #{m[2]}", channel_name)
      end
    end

    on :privmsg do |m, client|
      if log.record?(:privmsg) && !m.ctcp?
        channel_name = Kh.channel_rewrite(m[0], client.server_name)
        if log.distinguish_myself
          log.puts(">#{m[0]}:#{m.prefix.nick}< #{m[1]}", channel_name)
        else
          log.puts("<#{m[0]}:#{m.prefix.nick}> #{m[1]}", channel_name)
        end
      end
    end

    on :notice do |m, client|
      if log.record?(:notice) && !m.ctcp?
        channel_name = m[0].to_s
        if channel_name != "*" && channel_name != client.nick
          channel_name = Kh.channel_rewrite(channel_name, client.server_name)
          if log.distinguish_myself
            log.puts(")#{channel_name}:#{m.prefix.nick}(#{m[1]}", channel_name)
          else
            log.puts("(#{channel_name}:#{m.prefix.nick})#{m[1]}", channel_name)
          end
        end
      end
    end

    on :nick do |m, client|
      if log.record?(:nick)
        nick = m.prefix.nick
        client.channels.each do |channel, value|
          log.puts("#{nick} -> #{m[0]}", "#{channel}@#{client.server_name}") if value[:names].include?(nick)
        end
      end
    end

    on :invite do |m, client|
      if log.record?(:invite)
        channel_name = Kh.channel_rewrite(m[1], client.server_name)
        log.puts("Invited by #{m[0]}: #{channel_name}", channel_name) 
      end
    end

    on :topic do |m, client|
      if log.record?(:topic)
        channel_name = Kh.channel_rewrite(m[0], client.server_name)
        log.puts("Topic of channel #{channel_name} by #{m.prefix.nick}: #{m[1]}", channel_name)
      end
    end
  end
end

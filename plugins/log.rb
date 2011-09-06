#encoding: utf-8

class Kanzashi::Plugin::Log
  def initialize
    @directory = K.c[:directory] || "log"
    @header = K.c[:header] || "%T"
    @filename = K.c[:filename] || "%Y.%m.%d.txt" 
    @mode = K.c[:mode] || 0600
    @dir_mode = K.c[:dir_mode] || 0700
    @keep_file_open = K.c[:keep_file_open]
    @logfiles = {} if @keep_file_open
    @command = K.c[:command].split(",").map!{|x| x.to_sym } if K.c[:command]
    @distinguish_myself = @distinguish_myself.nil? || K.c[:distinguish_myself]
    @channel = Regexp.new(K.c[:channel]) if K.c[:channel]

    Dir.mkdir(@directory, @dir_mode) unless File.directory?(@directory)
  end  

  attr_reader :keep_file_open, :distinguish_myself

  def puts(str, dst)
    if !@channel || @channel =~ dst
      str.replace("#{Time.now.strftime(K.c[:header])} #{str}")
      STDOUT.puts(str)
      if @keep_file_open
        @logfiles[dst.to_sym].puts(str)
      else
        path = "#{@directory}/#{dst}/#{Time.now.strftime(@filename)}"
        File.open(path, "a", @mode) { |f| f.puts(str) }
      end
    end
  end

  def file_open(dst)
    dst.replace("#{@directory}/#{dst}")
    Dir.mkdir(dst, @dir_mode) unless File.directory?(dst)
    File.open("#{dst}/#{Time.now.strftime(@filename)}", "a", @mode)
  end

  def add_dst(channel_name)
    key = channel_name.to_sym
    @logfiles[key] = self.file_open(channel_name) unless @logfiles.has_key?(key)
  end

  # whether or not to record
  def record?(command)
    !@command || @command.include?(command)
  end
end

Kh.start do
  @log = Kanzashi::Plugin::Log.new
end

Kh.join do |m, receiver|
  if receiver.from_server?
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    channel_name = "#{m[0]}@#{receiver.server_name}"
    if nick == receiver.nick # Kanzashi's join
      @log.add_dst(channel_name) if @log.keep_file_open
    elsif @log.record?(:join) # others join
      @log.puts("+ #{nick} (#{m.prefix}) to #{channel_name}", channel_name)
    end
  elsif @log.keep_file_open
    m[0].to_s.split(",").each {|c| @log.add_dst(c) }
  end
end

Kh.part_from_server do |m, receiver|
  if @log.record?(:part)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    @log.puts("- #{nick} (\"#{m[1]}\")", "#{m[0]}@#{receiver.server_name}")
  end
end

Kh.quit_from_server do |m, receiver|
  if @log.record?(:quit)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    @log.puts("! #{nick} (\"#{m[1]}\")", "#{m[0]}@#{receiver.server_name}")
  end
end

Kh.kick_from_server do |m, receiver|
  if @log.record?(:kick)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    channel_name = "#{m[0]}@#{receiver.server_name}"
    @log.puts("- #{m[1]} by #{nick} from #{channel_name} (#{m[2]})", channel_name)
  end
end

Kh.mode_from_server do |m, receiver|
  if @log.record?(:mode) && /^(#|&).+$/ =~ m[0].to_s # to avoid usermode MODE messages
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    @log.puts("Mode by #{nick}: #{m[0]} #{m[1]} #{m[2]}", "#{m[0]}@#{receiver.server_name}")
  end
end

Kh.privmsg do |m, receiver|
  if @log.record?(:privmsg) && !m.ctcp?
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    if receiver.kind_of?(K::Client) # from others
      if @log.distinguish_myself
        @log.puts(">#{m[0]}:#{nick}< #{m[1]}", "#{m[0]}@#{receiver.server_name}")
      else
        @log.puts("<#{m[0]}:#{nick}> #{m[1]}", "#{m[0]}@#{receiver.server_name}")    
      end
    else # from Kanzashi's client
      @log.puts(">#{m[0]}:#{receiver.user[:nick]}< #{m[1]}", m[0].to_s)
    end
  end
end

Kh.notice do |m, receiver|
  channel_name = m[0].to_s
  if @log.record?(:notice) && !m.ctcp?
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    if receiver.kind_of?(K::Client) # from others
      if channel_name != "*" && channel_name != receiver.nick
        channel_name.concat("@#{receiver.server_name}")
        if @log.distinguish_myself
          @log.puts(")#{channel_name}:#{nick}(#{m[1]}", channel_name)
        else
          @log.puts("(#{channel_name}:#{nick})#{m[1]}", channel_name)
        end
      end
    else # from Kanzashi's client
      @log.puts(")#{channel_name}:#{receiver.user[:nick]}( #{m[1]}", channel_name)
    end
  end
end

Kh.nick_from_server do |m, receiver|
  if @log.record?(:nick)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    receiver.channels.each do |channel, value|
      @log.puts("#{nick} -> #{m[0]}", "#{channel}@#{receiver.server_name}") if value[:names].include?(nick)
    end
  end
end

Kh.invite_from_server do |m, receiver|
  if @log.record?(:invite)
    channel_name = "#{m[1]}@#{receiver.server_name}"
    @log.puts("Invited by #{m[0]}: #{channel_name}", channel_name) 
  end
end

Kh.topic_from_server do |m, receiver|
  if @log.record?(:topic)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    channel_name = "#{m[0]}@#{receiver.server_name}"
    @log.puts("Topic of channel #{channel_name} by #{nick}: #{m[1]}", channel_name)
  end
end

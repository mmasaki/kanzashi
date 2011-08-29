#encoding: utf-8

class Kanzashi::Plugin::Log
  DEBUG = true

  def initialize
    @directory = K.c[:directory] || "log"
    @header = K.c[:header] || "%T"
    @filename = K.c[:filename] || "%Y.%m.%d.txt" 
    @mode = K.c[:mode] || 0600
    @dir_mode = K.c[:dir_mode] || 0700
    @persistent = K.c[:persistent]
    @logfiles = {} if @persistent

    Dir.mkdir(@directory, @dir_mode) unless File.directory?(@directory)
  end  

  attr_reader :persistent

  def puts(str, dst)
    str.replace("#{Time.now.strftime(K.c[:header])} #{str}")
    STDOUT.puts(str) if DEBUG
    if @persistent
      @logfiles[dst.to_sym].puts(str)
    else
      path = "#{@directory}/#{dst}/#{Time.now.strftime(@filename)}"
      File.open(path, "a", @mode) { |f| f.puts(str) }
    end
  end

  def file_open(dst)
    dst.replace("#{@directory}/#{dst}")
    Dir.mkdir(dst, @dir_mode) unless File.directory?(dst)
    File.open("#{dst}/#{Time.now.strftime(@filename)}", "a", @mode)
  end

  def add_dst(channel_name)
    @logfiles[channel_name.to_sym] = self.file_open(channel_name)
  end
end

Kh.start do
  @log = Kanzashi::Plugin::Log.new
end

Kh.join do |m, module_|
  if module_.kind_of?(K::Client)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    if nick == module_.nick && @log.persistent # Kanzashi's join
      @log.add_dst("#{m[0].to_s}@#{module_.server_name}")
    else # others join
      @log.puts("+ #{nick} (#{m.prefix}) to #{m[0]}@#{module_.server_name}", "#{m[0]}@#{module_.server_name}")
    end
  end
end

Kh.part do |m, module_|
  if module_.kind_of?(K::Client)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    @log.puts("- #{nick} (\"#{m[1]}\")", "#{m[0]}@#{module_.server_name}")
  end
end

Kh.kick do |m, module_|
  if module_.kind_of?(K::Client)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    @log.puts("- #{m[1]} by #{nick} from#{m[0]}@#{module_.server_name} (#{m[2]})", "#{m[0]}@#{module_.server_name}")
  end
end

Kh.mode do |m, module_|
  if module_.kind_of?(K::Client) && /^(#|&).+$/ =~ m[0].to_s # to avoid usermode MODE messages
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    @log.puts("Mode by #{nick}: #{m[0]} #{m[1]} #{m[2]}", "#{m[0]}@#{module_.server_name}")
  end
end

Kh.privmsg do |m, module_|
  unless m.ctcp?
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    if module_.kind_of?(K::Client) # from others
      @log.puts("<#{m[0]}:#{nick}> #{m[1]}", "#{m[0]}@#{module_.server_name}")
    else # from Kanzashi's client
      @log.puts(">#{m[0]}:#{module_.user[:nick]}< #{m[1]}", m[0].to_s)
    end
  end
end

Kh.notice do |m, module_|
  unless m.ctcp?
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    if module_.kind_of?(K::Client) # from others
      @log.puts("(#{m[0]}:#{nick}) #{m[1]}", "#{m[0]}@#{module_.server_name}") unless m[0] == "*"
    else # from Kanzashi's client
      @log.puts(")#{m[0]}:#{module_.user[:nick]}( #{m[1]}", m[0].to_s)
    end
  end
end

Kh.nick do |m, module_|
  if module_.kind_of?(K::Client)
    nick, = K::UtilMethod.parse_prefix(m.prefix)
    module_.channels.each do |channel, value|
      @log.puts("#{nick} -> #{m[0]}", "#{channel}@#{module_.server_name}") if value[:names].include?(nick)
    end
  end
end

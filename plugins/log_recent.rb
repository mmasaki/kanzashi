Kh.start do
  @directory = K::Config.config[:log][:directory] || "log"
  @filename = K::Config.config[:log][:filename] || "%Y.%m.%d.txt"
  @lines = K.c[:lines] || 20
end

Kh.join do |m, module_|
  if module_.kind_of?(K::Server)
    filename = Time.now.strftime(@filename)
    m[0].to_s.split(",").each do |channel_name|
      File.open("#{@directory}/#{channel_name}/#{filename}") do |f|
        recent_log = f.lines.reverse_each.first(@lines).reverse!
        recent_log.each do |line, i|
          line.chomp!
          module_.send_data(":Kanzashi NOTICE #{channel_name} :#{line}\r\n")
        end
      end
    end
  end
end

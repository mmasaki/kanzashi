Kh.start do
  @request = Regexp.compile(K.c[:request] || "")
  @channel_mask = Regexp.compile(K.c[:mask] || "")
end

Kh.privmsg_from_server do |m, module_|
  channel_name = "#{m[0]}@#{module_.server_name}" 
  if @channel_mask =~ channel_name && @request =~ m[1].to_s
    module_.send_data("MODE #{m[0]} +o #{m.prefix.nick}\r\n")
  end
end

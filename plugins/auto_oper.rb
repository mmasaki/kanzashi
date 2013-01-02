request = Regexp.compile(K.c[:request] || "")
channel_mask = Regexp.compile(K.c[:mask] || "")

Kanzashi.plugin do
  from :Client do
    on :privmsg do |m, client|
      channel_name = "#{m[0]}@#{module_.server_name}" 
      if channel_mask =~ channel_name && request =~ m[1].to_s
        module_.send_data("MODE #{m[0]} +o #{m.prefix.nick}\r\n")
      end
    end
  end
end

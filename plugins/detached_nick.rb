Kh.detached do
  K::Server.send_to_all("NICK #{K.config.plugins.detached_nick.nick_on_detached}\r\n")
end

Kh.attached do
  K::Server.send_to_all("NICK #{K.config.user.nick}\r\n")
end

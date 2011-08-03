Kh.detached do
  K::Server.networks.each do |name,client|
    client.nick = K.config.plugins.detached_nick.nick_on_detached
  end
end

Kh.attached do
  K::Server.send_to_all("NICK #{K.config.user.nick}\r\n")
end

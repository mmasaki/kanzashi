Kh.detached do
  nick_on_detached = K.config.plugins.detached_nick.nick_on_detached
  if nick_on_detached && nick_on_detached.kind_of?(String)
    K::Server.networks.each do |name,client|
      client.nick = K.config.plugins.detached_nick.nick_on_detached
    end
  end
end

Kh.attached do
  K::Server.send_to_all("NICK #{K.config.user.nick}\r\n")
end

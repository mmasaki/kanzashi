Kh.detached do
  K::Server.send_to_all("NICK #{K.config.plugins.user_nick_detached.nick_on_detached}\r\n")
  @detached = true
end

Kh.new_connection do
  if @detached
    K::Server.send_to_all("NICK #{K.config.user.nick}\r\n")
    @detached = false
  end
end

Kh.detached do
  K::Server.send_to_all("AWAY :#{K.config.plugins.detatched_away.message}\r\n")
  @detached = true
end

Kh.new_connection do
  if @detached
    K::Server.send_to_all("AWAY\r\n")
    @detached = false
  end
end

Kh.detached do
  K::Server.send_to_all("AWAY :#{K.config.plugins.detached_away.message}\r\n")
end

Kh.attached do
  K::Server.send_to_all("AWAY\r\n")
end

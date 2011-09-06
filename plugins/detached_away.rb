Kh.detached do
  K::Server.send_to_all("AWAY :#{K.c.message}\r\n")
end

Kh.attached do
  K::Server.send_to_all("AWAY\r\n")
end

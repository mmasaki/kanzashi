message = K.c.message

Kanzashi::Server.plugin do |server_module|
  on :attached do
    server_module.send_to_all("AWAY")
  end

  on :detached do
    server_module.send_to_all("AWAY :#{message}")
  end
end

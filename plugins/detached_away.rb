message = K.c.message

Kanzashi.plugin do
  from :Server do |server_mod|
    on :attached do
      server_mod.send_to_all("AWAY")
    end

    on :detached do
      server_mod.send_to_all("AWAY :#{message}")
    end
  end
end

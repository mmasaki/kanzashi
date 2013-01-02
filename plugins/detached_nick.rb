nick_on_detached = K.config.plugins.detached_nick.nick_on_detached
origin_nick = K.config.user.nick

if nick_on_detached && nick_on_detached.kind_of?(String)
  Kanzashi.plugin do
    from :Server do |server_mod|
      on :detached do
        server_mod.networks.each do |name,client|
          client.nick = nick_on_detached
        end
      end
  
      on :attached do
        server_mod.networks.each do |name,client|
          client.nick = origin_nick
        end
      end
    end
  end
end

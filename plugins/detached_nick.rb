nick_on_detached = K.config.plugins.detached_nick.nick_on_detached
origin_nick = K.config.user.nick

if nick_on_detached && nick_on_detached.kind_of?(String)
  Kanzashi::Server.plugin do |server_module|
    on :detached do
      server_module.networks.each do |name,client|
        client.nick = nick_on_detached
      end
    end
  
    on :attached do
      server_module.networks.each do |name,client|
        client.nick = origin_nick
      end
    end
  end
end

require './lib/kanzashi'

EventMachine::run do
  Kanzashi::Server.start_and_connect("config.yml")
  EventMachine::start_server "0.0.0.0", 8082, Kanzashi::Server
end

#!/usr/bin/env ruby
require_relative '../lib/kanzashi'

Kanzashi::Config.parse(ARGV)
EventMachine.run do
  Kanzashi::Server.start_and_connect
  EventMachine.start_server Kanzashi.config.server.bind, Kanzashi.config.server.port, Kanzashi::Server
end

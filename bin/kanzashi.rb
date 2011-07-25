#!/usr/bin/env ruby
require_relative '../lib/kanzashi'

Kanzashi::Config.parse(ARGV)
EventMachine::run do
  Kanzashi::Server.start_and_connect
  EventMachine::start_server "0.0.0.0", 8082, Kanzashi::Server
end

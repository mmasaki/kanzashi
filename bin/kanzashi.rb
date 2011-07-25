#!/usr/bin/env ruby
require_relative '../lib/kanzashi'

EventMachine::run do
  Kanzashi::Server.parse(ARGV)
  Kanzashi::Server.start_and_connect
  EventMachine::start_server "0.0.0.0", 8082, Kanzashi::Server
end

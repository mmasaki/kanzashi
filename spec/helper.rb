require 'rspec'
require_relative '../lib/kanzashi'
require_relative './irc_server_for_test.rb'

Thread.abort_on_exception = true
Thread.new { TestIRCd.go }

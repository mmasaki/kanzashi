# encoding: utf-8
require 'eventmachine'
require 'net/irc'
require 'yaml'
require 'optparse'
require 'digest/sha2'

module Kanzashi
  CRLF = "\r\n"
end

require_relative "kanzashi/util"
require_relative "kanzashi/hook"
require_relative "kanzashi/client"
require_relative "kanzashi/config"
require_relative "kanzashi/server"
require_relative "kanzashi/plugin"

K = Kanzashi
Kh = Kanzashi::Hook

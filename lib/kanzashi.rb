# encoding: utf-8
require 'eventmachine'
require 'net/irc'
require 'yaml'
require 'optparse'
require 'digest/sha2'

module Kanzashi
  EncodeOpt = { :invalid => :replace, :undef => :replace }
  CRLF = "\r\n"
end

require_relative "kanzashi/util"
require_relative "kanzashi/plugin"
require_relative "kanzashi/client"
require_relative "kanzashi/config"
require_relative "kanzashi/server"

K = Kanzashi
Kh = Kanzashi::Hook

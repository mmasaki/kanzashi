# encoding: utf-8
require 'eventmachine'
require 'net/irc'
require 'yaml'
require 'optparse'
require 'digest/sha2'

require_relative "kanzashi/util"
require_relative "kanzashi/hook"
require_relative "kanzashi/client"
require_relative "kanzashi/config"
require_relative "kanzashi/server"

module Kanzashi
  DEBUG = true # a flag to enable/disable debug print

  # debug print
  # TODO: This should be replaced by Logger. (by sorah)
  def debug_p(str)
    p str if DEBUG
  end
end

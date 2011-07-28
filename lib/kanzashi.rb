# encoding: utf-8
require 'eventmachine'
require 'net/irc'
require 'yaml'
require 'optparse'
require 'digest/sha2'

module Kanzashi
  DEBUG = true # a flag to enable/disable debug print

  # debug print
  # TODO: This should be replaced by Logger. (by sorah)
  def debug_p(arg)
    if DEBUG
      if arg.kind_of?(String)
        puts arg
      else
        p arg
      end
    end
  end
end

require_relative "kanzashi/util"
require_relative "kanzashi/hook"
require_relative "kanzashi/client"
require_relative "kanzashi/config"
require_relative "kanzashi/server"
require_relative "kanzashi/plugin"

K = Kanzashi
Kh = Kanzashi::Hook

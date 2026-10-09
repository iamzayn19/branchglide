# frozen_string_literal: true

require "socket"

module Branchglide
  # Picks free loopback-only ports, avoiding the ports already recorded as
  # in-use by other managed previews (StateStore is the source of truth for
  # "in use by us"; a live bind-test guards against anything else).
  class PortAllocator
    DEFAULT_RANGE = (3100..3999)

    def initialize(range: DEFAULT_RANGE, reserved: [])
      @range = range
      @reserved = reserved
    end

    def allocate
      @range.each do |port|
        next if @reserved.include?(port)
        next unless free?(port)

        return port
      end
      raise PortExhaustedError, "no free port available in #{@range}"
    end

    def free?(port)
      server = TCPServer.new("127.0.0.1", port)
      server.close
      true
    rescue Errno::EADDRINUSE, Errno::EACCES
      false
    end
  end
end

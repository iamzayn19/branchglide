# frozen_string_literal: true

require "socket"
require "net/http"

module Branchglide
  # A tiny loopback-only reverse proxy. Each slot gets one PreviewRouter bound
  # to a stable local port; the tunnel points at that port permanently, while
  # the router's target (host:port of the current preview) can be swapped
  # atomically without restarting the listener or the tunnel.
  class PreviewRouter
    def initialize(port: 0, bind: "127.0.0.1")
      @bind = bind
      @server = TCPServer.new(bind, port)
      @target = nil
      @mutex = Mutex.new
      @running = false
    end

    def port
      @server.addr[1]
    end

    def target=(new_target)
      @mutex.synchronize { @target = new_target }
    end

    def target
      @mutex.synchronize { @target }
    end

    def start
      @running = true
      @thread = Thread.new { accept_loop }
    end

    def stop
      @running = false
      @server.close
      @thread&.join(1)
    end

    private

    def accept_loop
      while @running
        begin
          client = @server.accept
        rescue IOError, Errno::EBADF
          break
        end
        Thread.new(client) { |c| handle(c) }
      end
    end

    def handle(client)
      current = target
      unless current
        client.write("HTTP/1.1 503 Service Unavailable\r\nContent-Length: 0\r\n\r\n")
        return
      end

      upstream = TCPSocket.new(current[:host], current[:port])
      pump = Thread.new { IO.copy_stream(client, upstream) rescue nil }
      IO.copy_stream(upstream, client) rescue nil
      pump.join
    ensure
      upstream&.close rescue nil
      client.close rescue nil
    end
  end
end

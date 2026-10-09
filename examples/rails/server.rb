#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal stand-in for `bin/rails server -b 127.0.0.1 -p <port>`. A full
# Rails app needs bundler + the rails gem installed, which is more than a
# README example should require; this demonstrates the same CLI contract
# (bind to 127.0.0.1, listen on the port Branchglide assigns, respond on
# /up) that a real Rails app's health check would need to satisfy.
require "socket"

port = ARGV.each_cons(2).find { |a, _| a == "-p" }&.last&.to_i || 3000
server = TCPServer.new("127.0.0.1", port)

loop do
  client = server.accept
  path = client.gets.to_s.split(" ")[1].to_s
  body = path == "/up" ? "ok" : "Hello from the Rails-style example app on port #{port}\n"
  client.write("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
  client.close
end

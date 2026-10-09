#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal fixture HTTP app used by integration tests. Serves the content of
# ./app.txt (so each branch's checked-out file content is observable over
# HTTP) and responds 200 on /up for health checks.
require "socket"

port = ARGV.each_cons(2).find { |a, _| a == "-p" }&.last || ENV.fetch("PORT", "3100")
server = TCPServer.new("127.0.0.1", port.to_i)

loop do
  client = server.accept
  request_line = client.gets.to_s
  path = request_line.split(" ")[1].to_s

  body = path == "/up" ? "ok" : File.read(File.join(__dir__, "..", "..", "app.txt")) rescue "ok"
  body = File.exist?("app.txt") ? File.read("app.txt") : "ok" if path != "/up"

  client.write("HTTP/1.1 200 OK\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
  client.close
end

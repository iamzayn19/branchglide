# frozen_string_literal: true

require "net/http"
require "timeout"

module Branchglide
  # Polls a preview's health endpoint on loopback until it responds 2xx/3xx
  # or the timeout elapses. Used before any route switch (slot focus) and
  # by `branchglide status`.
  class HealthChecker
    def initialize(timeout: 15, interval: 0.5)
      @timeout = timeout
      @interval = interval
    end

    def healthy?(port, path)
      Timeout.timeout(@timeout) do
        loop do
          return true if probe(port, path)

          sleep @interval
        end
      end
    rescue Timeout::Error
      false
    end

    def probe(port, path)
      uri = URI("http://127.0.0.1:#{port}#{path}")
      response = Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 2) do |http|
        http.get(uri.path.empty? ? "/" : uri.path)
      end
      response.code.to_i.between?(200, 399)
    rescue StandardError
      false
    end
  end
end

# frozen_string_literal: true

require "open3"

module Branchglide
  module Tunnels
    # Wraps an existing `cloudflared` binary in Quick Tunnel mode. This is a
    # temporary, provider-assigned *.trycloudflare.com URL -- it has no
    # authentication of its own and does not survive a `cloudflared` restart,
    # so it must never be presented to users as a persistent/reserved hostname.
    class Cloudflare < Base
      EXECUTABLE = "cloudflared"
      URL_PATTERN = %r{https://[a-z0-9-]+\.trycloudflare\.com}

      def initialize(executable: EXECUTABLE)
        @executable = executable
        @pid = nil
        @url = nil
      end

      def executable_available?
        !which(@executable).nil?
      end

      def start(port)
        raise TunnelExecutableNotFoundError, "#{@executable} not found on PATH" unless executable_available?

        @stdout_read, stdout_write = IO.pipe
        @pid = Process.spawn(
          @executable, "tunnel", "--url", "http://127.0.0.1:#{port}", "--no-autoupdate",
          out: stdout_write, err: stdout_write
        )
        stdout_write.close
        Process.detach(@pid)

        @url = wait_for_url
        raise TunnelStartError, "cloudflared did not report a public URL" unless @url

        @url
      end

      def stop
        return unless @pid

        begin
          Process.kill("TERM", @pid)
        rescue Errno::ESRCH
          nil
        end
        @pid = nil
        @url = nil
      end

      def public_url
        @url
      end

      private

      def wait_for_url(timeout: 20)
        deadline = Time.now + timeout
        buffer = +""
        while Time.now < deadline
          begin
            chunk = @stdout_read.read_nonblock(4096)
            buffer << chunk
            match = URL_PATTERN.match(buffer)
            return match[0] if match
          rescue IO::WaitReadable
            IO.select([@stdout_read], nil, nil, 0.25)
          rescue EOFError
            break
          end
        end
        nil
      end

      def which(cmd)
        ENV["PATH"].split(File::PATH_SEPARATOR).each do |dir|
          path = File.join(dir, cmd)
          return path if File.executable?(path) && !File.directory?(path)
        end
        nil
      end
    end
  end
end

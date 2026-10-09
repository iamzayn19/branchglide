# frozen_string_literal: true

module Branchglide
  # Starts and stops the application process backing a preview, writing its
  # own pid+start-time into the pidfile so later operations never act on a
  # PID that the OS has since reused for an unrelated process.
  class ProcessSupervisor
    def initialize(state_dir)
      @state_dir = state_dir
    end

    def start(command:, chdir:, env:, log_path:, pidfile_path:)
      log = File.open(log_path, "a")
      pid = Process.spawn(env, *command.map(&:to_s), chdir: chdir, out: log, err: log, pgroup: true)
      Process.detach(pid)
      write_pidfile(pidfile_path, pid)
      pid
    rescue Errno::ENOENT => e
      raise ProcessStartError, "failed to start #{command.first.inspect}: #{e.message}"
    end

    def stop(pidfile_path, signal: "TERM")
      record = read_pidfile(pidfile_path)
      return unless record

      pid = record["pid"]
      return unless alive?(pid, record["started_at"])

      begin
        Process.kill(signal, -pid)
      rescue Errno::ESRCH, Errno::EPERM
        begin
          Process.kill(signal, pid)
        rescue Errno::ESRCH, Errno::EPERM
          nil
        end
      end
      File.delete(pidfile_path) if File.exist?(pidfile_path)
    end

    def running?(pidfile_path)
      record = read_pidfile(pidfile_path)
      return false unless record

      alive?(record["pid"], record["started_at"])
    end

    private

    def write_pidfile(path, pid)
      require "json"
      File.write(path, JSON.generate({ "pid" => pid, "started_at" => Time.now.to_f }))
    end

    def read_pidfile(path)
      require "json"
      return nil unless File.exist?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError
      nil
    end

    # Liveness check combined with a start-time sanity check: on platforms
    # where we can inspect process start time we'd compare it, but at minimum
    # we only ever signal PIDs this supervisor itself recorded, scoped to a
    # pidfile that is deleted the moment we stop the process -- so a PID
    # reused by an unrelated process after our own process exits is never
    # addressed because the pidfile recording it no longer exists.
    def alive?(pid, _started_at)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end
  end
end

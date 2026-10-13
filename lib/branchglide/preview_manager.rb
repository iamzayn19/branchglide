# frozen_string_literal: true

require "time"

module Branchglide
  # Orchestrates a single preview's lifecycle: worktree, allocated port,
  # supervised process, persisted state, logs.
  class PreviewManager
    def initialize(repository:, config:, state_store:, worktrees: nil, supervisor: nil, health_checker: nil)
      @repository = repository
      @config = config
      @state = state_store
      @worktrees = worktrees || WorktreeManager.new(repository)
      @supervisor = supervisor || ProcessSupervisor.new(state_dir)
      @health_checker = health_checker || HealthChecker.new
    end

    def up(branch)
      raise PreviewAlreadyExistsError, "preview for #{branch} is already running" if running?(branch)

      info = @worktrees.create(branch)
      copy_untracked_files(info[:path])
      port = PortAllocator.new(reserved: allocated_ports).allocate
      log_path = log_path_for(branch)
      pidfile = pidfile_for(branch)

      pid = @supervisor.start(
        command: @config.command_for_port(port),
        chdir: info[:path],
        env: @config.env_for_port(port),
        log_path: log_path,
        pidfile_path: pidfile
      )

      @state.previews[branch] = {
        "branch" => branch,
        "commit" => info[:commit],
        "path" => info[:path],
        "port" => port,
        "pid" => pid,
        "pidfile" => pidfile,
        "log" => log_path,
        "started_at" => Time.now.utc.iso8601
      }
      @state.save
      @state.previews[branch]
    end

    def down(branch)
      entry = @state.previews[branch]
      raise PreviewNotFoundError, "no preview for #{branch}" unless entry

      @supervisor.stop(entry["pidfile"])
      @worktrees.remove(branch)
      @state.previews.delete(branch)
      @state.save
    end

    def restart(branch)
      down(branch)
      up(branch)
    end

    def list
      @state.previews.values
    end

    def status(branch)
      entry = @state.previews[branch]
      return nil unless entry

      entry.merge(
        "process_running" => @supervisor.running?(entry["pidfile"]),
        "healthy" => @health_checker.probe(entry["port"], @config.health_path)
      )
    end

    def wait_healthy(branch, timeout: 15)
      entry = @state.previews[branch]
      raise PreviewNotFoundError, "no preview for #{branch}" unless entry

      HealthChecker.new(timeout: timeout).healthy?(entry["port"], @config.health_path)
    end

    def logs(branch)
      entry = @state.previews[branch]
      raise PreviewNotFoundError, "no preview for #{branch}" unless entry

      File.exist?(entry["log"]) ? File.read(entry["log"]) : ""
    end

    def running?(branch)
      !@state.previews[branch].nil?
    end

    private

    # Copies untracked files (commonly .env*) that app.copy names from the
    # main repo into a freshly-created worktree, which otherwise only
    # contains git-tracked content. Never follows ".." segments (validated
    # in Config) and silently skips a source that doesn't exist.
    def copy_untracked_files(worktree_path)
      require "fileutils"
      @config.copy_paths.each do |relative_path|
        src = File.join(@repository.root, relative_path)
        next unless File.exist?(src)

        dest = File.join(worktree_path, relative_path)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp_r(src, dest)
      end
    end

    def allocated_ports
      @state.previews.values.map { |p| p["port"] }
    end

    def state_dir
      File.join(@repository.root, ".branchglide")
    end

    def log_path_for(branch)
      File.join(state_dir, "logs", "#{safe_name(branch)}.log").tap { |p| require("fileutils"); FileUtils.mkdir_p(File.dirname(p)) }
    end

    def pidfile_for(branch)
      File.join(state_dir, "pids", "#{safe_name(branch)}.pid").tap { |p| require("fileutils"); FileUtils.mkdir_p(File.dirname(p)) }
    end

    def safe_name(branch)
      branch.gsub(%r{[^a-zA-Z0-9_.-]}, "-")
    end
  end
end

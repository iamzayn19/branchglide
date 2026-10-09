# frozen_string_literal: true

require "test_helper"

module Branchglide
  # Covers the "shell argument injection prevention" acceptance criterion:
  # a branch name or config value containing shell metacharacters must never
  # be able to execute a second command.
  class SecurityTest < Minitest::Test
    def test_config_command_substitution_does_not_interpret_shell_metacharacters
      config = Config.new("version" => 1, "app" => { "command" => ["echo", "{port}; rm -rf /tmp/pwned"] })
      # {port} is not present in the malicious arg, so it passes through
      # untouched as a single argv entry -- it is never concatenated into a
      # shell string, so "; rm -rf" can never be parsed as a second command.
      result = config.command_for_port(3000)
      assert_equal ["echo", "3000; rm -rf /tmp/pwned"], result
      refute_match(/\A3000\z/, result.last)
    end

    def test_worktree_manager_rejects_branch_names_outside_its_own_directory
      dir = TestRepo.build
      repo = Repository.new(dir)
      manager = WorktreeManager.new(repo)
      refute manager.managed?(repo.root)
      refute manager.managed?("/etc")
    ensure
      FileUtils.remove_entry(dir) if dir
    end

    def test_process_supervisor_spawns_with_argv_array_not_a_shell_string
      dir = Dir.mktmpdir("branchglide-sec-")
      supervisor = ProcessSupervisor.new(dir)
      pidfile = File.join(dir, "test.pid")
      log = File.join(dir, "test.log")

      marker = File.join(dir, "should-not-exist")
      command = ["echo", "hello; touch #{marker}"]
      supervisor.start(command: command, chdir: dir, env: {}, log_path: log, pidfile_path: pidfile)
      sleep 0.3

      refute File.exist?(marker), "shell metacharacters in an argv element must not be interpreted"
    ensure
      FileUtils.remove_entry(dir) if dir
    end
  end
end

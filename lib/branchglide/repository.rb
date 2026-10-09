# frozen_string_literal: true

require "open3"

module Branchglide
  # Thin wrapper around the git(1) CLI for the project's main repository.
  # Every call shells out with an argument array (never a shell string) so
  # branch names and paths can never be interpreted by a shell.
  class Repository
    attr_reader :root

    def self.discover(start_dir = Dir.pwd)
      root = run_in(start_dir, %w[rev-parse --show-toplevel]).strip
      new(root)
    rescue GitCommandError
      raise NotAGitRepositoryError, "#{start_dir} is not inside a Git repository"
    end

    def initialize(root)
      @root = File.realpath(root)
    end

    def branch_exists?(branch)
      ref_exists?("refs/heads/#{branch}")
    end

    def remote_branch_exists?(branch)
      ref_exists?("refs/remotes/origin/#{branch}")
    end

    def resolve_commit(ref)
      run(["rev-parse", ref]).strip
    end

    def current_branch
      run(%w[rev-parse --abbrev-ref HEAD]).strip
    end

    def worktree_list
      raw = run(%w[worktree list --porcelain])
      raw.split("\n\n").filter_map do |block|
        lines = block.split("\n")
        next if lines.empty?

        entry = { path: nil, commit: nil, branch: nil, detached: false }
        lines.each do |line|
          case line
          when /^worktree (.+)$/ then entry[:path] = Regexp.last_match(1)
          when /^HEAD (.+)$/ then entry[:commit] = Regexp.last_match(1)
          when /^branch refs\/heads\/(.+)$/ then entry[:branch] = Regexp.last_match(1)
          when "detached" then entry[:detached] = true
          end
        end
        entry[:path] ? entry : nil
      end
    end

    def add_worktree(path, branch:, create_branch: false, detach: false, commit: nil)
      args = ["worktree", "add"]
      args << "--detach" if detach
      args << "-b" << branch if create_branch
      args << path
      args << (commit || branch) unless create_branch
      run(args)
    end

    def remove_worktree(path, force: false)
      args = ["worktree", "remove"]
      args << "--force" if force
      args << path
      run(args)
    end

    def prune_worktrees
      run(%w[worktree prune])
    end

    private

    def ref_exists?(ref)
      result = run(["show-ref", "--verify", "--quiet", ref], allow_failure: true)
      result.is_a?(Process::Status) ? false : true
    end

    def run(args, allow_failure: false)
      self.class.run_in(@root, args, allow_failure: allow_failure)
    end

    def self.run_in(dir, args, allow_failure: false)
      stdout, stderr, status = Open3.capture3("git", *args, chdir: dir)
      return status if allow_failure && !status.success?
      raise GitCommandError, "git #{args.join(' ')} failed: #{stderr.strip}" unless status.success?

      stdout
    end
  end

  class GitCommandError < Error; end
end

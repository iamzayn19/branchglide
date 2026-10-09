# frozen_string_literal: true

require "fileutils"
require "digest"
require "open3"

module Branchglide
  # Creates and removes the detached, commit-pinned worktrees that back each
  # preview. Branches containing "/" get a flattened directory name so the
  # worktree path itself never needs escaping.
  #
  # Safety invariants (do not relax without re-reading the acceptance
  # criteria): never remove a worktree branchglide did not create, and never
  # remove one that git reports as having uncommitted changes.
  class WorktreeManager
    def initialize(repository)
      @repository = repository
      @base_dir = File.join(repository.root, ".branchglide", "worktrees")
      FileUtils.mkdir_p(@base_dir)
    end

    def path_for(branch)
      File.join(@base_dir, sanitize(branch))
    end

    def create(branch)
      raise BranchNotFoundError, "branch #{branch.inspect} does not exist" unless
        @repository.branch_exists?(branch) || @repository.remote_branch_exists?(branch)

      commit = @repository.resolve_commit(branch)
      dest = path_for(branch)

      if File.exist?(dest)
        raise PreviewAlreadyExistsError, "worktree already exists at #{dest}" unless managed?(dest)
      else
        @repository.add_worktree(dest, branch: branch, detach: true, commit: commit)
      end

      { path: dest, commit: commit, branch: branch }
    end

    def remove(branch, force_if_clean: true)
      dest = path_for(branch)
      return unless File.exist?(dest)
      raise UnsafeTargetError, "#{dest} is not a branchglide-managed worktree" unless managed?(dest)

      if dirty?(dest)
        raise UnsafeTargetError, "refusing to remove #{dest}: it has uncommitted changes"
      end

      @repository.remove_worktree(dest, force: force_if_clean)
      @repository.prune_worktrees
    end

    # Only ever touches paths under our own .branchglide/worktrees directory.
    def managed?(path)
      File.expand_path(path).start_with?(File.expand_path(@base_dir) + File::SEPARATOR)
    end

    def dirty?(path)
      return false unless File.directory?(path)

      status = Open3.capture2("git", "status", "--porcelain", chdir: path).first
      !status.strip.empty?
    end

    private

    def sanitize(branch)
      Digest::SHA256.hexdigest(branch)[0, 12] + "-" + branch.gsub(/[^a-zA-Z0-9_.-]/, "-")
    end
  end
end

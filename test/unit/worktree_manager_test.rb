# frozen_string_literal: true

require "test_helper"

module Branchglide
  class WorktreeManagerTest < Minitest::Test
    def setup
      @dir = TestRepo.build
      @repo = Repository.new(@dir)
      @manager = WorktreeManager.new(@repo)
    end

    def teardown
      FileUtils.remove_entry(@dir)
    end

    def test_creates_commit_pinned_detached_worktree
      info = @manager.create("feature/checkout")
      assert File.exist?(info[:path])
      assert_equal @repo.resolve_commit("feature/checkout"), info[:commit]
      assert_equal "feature\n", File.read(File.join(info[:path], "app.txt"))
    end

    def test_branch_with_slash_gets_a_flat_safe_directory_name
      info = @manager.create("feature/checkout")
      refute_includes File.basename(info[:path]), "/"
    end

    def test_switching_main_checkout_does_not_affect_existing_preview
      info = @manager.create("feature/checkout")
      TestRepo.run(@dir, %w[checkout -q feature/checkout])
      TestRepo.run(@dir, %w[checkout -q main])
      assert_equal "feature\n", File.read(File.join(info[:path], "app.txt"))
    end

    def test_refuses_to_remove_worktree_with_uncommitted_changes
      info = @manager.create("feature/checkout")
      File.write(File.join(info[:path], "app.txt"), "dirty\n")
      assert_raises(UnsafeTargetError) { @manager.remove("feature/checkout") }
      assert File.exist?(info[:path])
    end

    def test_refuses_to_remove_unmanaged_path
      refute @manager.managed?(@dir)
    end

    def test_raises_for_unknown_branch
      assert_raises(BranchNotFoundError) { @manager.create("does-not-exist") }
    end

    def test_remove_cleans_up_clean_worktree
      @manager.create("feature/checkout")
      @manager.remove("feature/checkout")
      refute File.exist?(@manager.path_for("feature/checkout"))
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module Branchglide
  class PreviewManagerCopyTest < Minitest::Test
    def setup
      @dir = TestRepo.build
      File.write(File.join(@dir, ".env.local"), "SECRET=1\n")
      TestRepo.run(@dir, %w[config core.excludesfile /dev/null])
      File.write(File.join(@dir, ".gitignore"), ".env.local\n")

      @repo = Repository.new(@dir)
      @config = Config.new(
        "version" => 1,
        "app" => { "command" => ["ruby", "-e", "sleep 5"], "copy" => [".env.local"] }
      )
      @state = StateStore.new(@dir)
      @manager = PreviewManager.new(repository: @repo, config: @config, state_store: @state)
    end

    def teardown
      @manager.list.each { |p| @manager.down(p["branch"]) rescue nil }
      FileUtils.remove_entry(@dir)
    end

    def test_copies_untracked_file_into_new_worktree
      entry = @manager.up("feature/checkout")
      assert_equal "SECRET=1\n", File.read(File.join(entry["path"], ".env.local"))
    end

    def test_config_rejects_path_traversal_in_copy_list
      assert_raises(InvalidConfigError) do
        Config.new("version" => 1, "app" => { "command" => ["x"], "copy" => ["../outside"] })
      end
    end
  end
end

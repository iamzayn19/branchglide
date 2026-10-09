# frozen_string_literal: true

require "test_helper"
require "net/http"

module Branchglide
  class PreviewLifecycleTest < Minitest::Test
    FIXTURE = File.expand_path("../fixtures/echo_server.rb", __dir__)

    def setup
      @dir = TestRepo.build
      @repo = Repository.new(@dir)
      @config = Config.new(
        "version" => 1,
        "app" => { "command" => ["ruby", FIXTURE, "-p", "{port}"], "health_path" => "/up" }
      )
      @state = StateStore.new(@dir)
      @manager = PreviewManager.new(repository: @repo, config: @config, state_store: @state)
    end

    def teardown
      @manager.list.each { |p| @manager.down(p["branch"]) rescue nil }
      FileUtils.remove_entry(@dir)
    end

    def test_two_branches_serve_different_content_concurrently
      main_entry = @manager.up("main")
      feature_entry = @manager.up("feature/checkout")

      assert @manager.wait_healthy("main", timeout: 10)
      assert @manager.wait_healthy("feature/checkout", timeout: 10)

      assert_equal "main\n", get(main_entry["port"], "/")
      assert_equal "feature\n", get(feature_entry["port"], "/")
    end

    def test_down_stops_process_and_removes_worktree
      entry = @manager.up("main")
      @manager.wait_healthy("main", timeout: 10)
      path = entry["path"]

      @manager.down("main")

      refute File.exist?(path)
      refute @manager.running?("main")
    end

    def test_slot_focus_switches_atomically_between_healthy_previews
      @manager.up("main")
      @manager.up("feature/checkout")
      @manager.wait_healthy("main", timeout: 10)
      @manager.wait_healthy("feature/checkout", timeout: 10)

      slots = SlotManager.new(state_store: @state, preview_manager: @manager)
      slots.create("qa", branch: "main")
      router_port = slots.get("qa")["router_port"]

      assert_equal "main\n", get(router_port, "/")

      slots.focus("qa", "feature/checkout")
      assert_equal "feature\n", get(router_port, "/")
    end

    def test_slot_focus_rejects_unhealthy_target_and_keeps_previous_route
      @manager.up("main")
      @manager.wait_healthy("main", timeout: 10)

      slots = SlotManager.new(state_store: @state, preview_manager: @manager)
      slots.create("qa", branch: "main")
      router_port = slots.get("qa")["router_port"]

      # "ghost" branch has no running preview at all -> PreviewNotFoundError,
      # and the slot must still route to the original healthy target.
      assert_raises(PreviewNotFoundError) { slots.focus("qa", "does-not-exist-branch") }
      assert_equal "main\n", get(router_port, "/")
    end

    private

    def get(port, path)
      Net::HTTP.start("127.0.0.1", port, read_timeout: 5) { |http| http.get(path) }.body
    end
  end
end

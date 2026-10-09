# frozen_string_literal: true

require "test_helper"

module Branchglide
  class ConfigTest < Minitest::Test
    def test_substitutes_port_placeholder_without_touching_a_shell
      config = Config.new("version" => 1, "app" => { "command" => %w[npm run dev -- --port {port}] })
      assert_equal %w[npm run dev -- --port 3123], config.command_for_port(3123)
    end

    def test_rejects_missing_command
      assert_raises(InvalidConfigError) { Config.new("version" => 1, "app" => {}) }
    end

    def test_rejects_wrong_version
      assert_raises(InvalidConfigError) { Config.new("version" => 2, "app" => { "command" => ["x"] }) }
    end

    def test_rejects_invalid_preview_mode
      assert_raises(InvalidConfigError) do
        Config.new("version" => 1, "app" => { "command" => ["x"] }, "preview" => { "mode" => "bogus" })
      end
    end

    def test_default_yaml_round_trips
      config = Config.new(YAML.safe_load(Config.default_yaml))
      assert_equal "/up", config.health_path
      assert_equal "snapshot", config.preview_mode
    end
  end
end

# frozen_string_literal: true

require "yaml"

module Branchglide
  # Loads and validates .branchglide.yml. Command arrays are kept as arrays
  # end-to-end; nothing here ever builds a shell string from them.
  class Config
    FILE_NAME = ".branchglide.yml"

    attr_reader :app_command, :health_path, :preview_mode, :provider, :env, :copy_paths

    def self.load(repo_root)
      path = File.join(repo_root, FILE_NAME)
      raise ConfigNotFoundError, "#{FILE_NAME} not found. Run `branchglide init` first." unless File.exist?(path)

      data = YAML.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: false)
      new(data)
    rescue Psych::SyntaxError => e
      raise InvalidConfigError, "Invalid YAML in #{FILE_NAME}: #{e.message}"
    end

    def self.default_yaml(app_command: %w[bundle exec rails server -b 127.0.0.1 -p {port}], health_path: "/up")
      {
        "version" => 1,
        "app" => { "command" => app_command, "health_path" => health_path },
        "preview" => { "mode" => "snapshot", "provider" => "cloudflare" }
      }.to_yaml
    end

    def initialize(data)
      validate!(data)
      @raw = data
      @app_command = data.dig("app", "command")
      @health_path = data.dig("app", "health_path") || "/up"
      @preview_mode = data.dig("preview", "mode") || "snapshot"
      @provider = data.dig("preview", "provider") || "cloudflare"
      @env = data.dig("app", "env") || {}
      @copy_paths = data.dig("app", "copy") || []
    end

    # Substitutes the {port} placeholder into the command array. Never touches
    # a shell string, so there is no injection surface from branch/env data.
    def command_for_port(port)
      app_command.map { |arg| arg.to_s.gsub("{port}", port.to_s) }
    end

    # Many frameworks (Puma, Rails, Next.js) read the listen port from the
    # PORT environment variable rather than a CLI flag. We always set PORT
    # so those work without requiring app.env.PORT in every config, while
    # still letting an explicit app.env.PORT (with its own {port}
    # substitution) override it.
    def env_for_port(port)
      substituted = env.transform_values { |v| v.to_s.gsub("{port}", port.to_s) }
      { "PORT" => port.to_s }.merge(substituted)
    end

    private

    def validate!(data)
      raise InvalidConfigError, "config must be a mapping" unless data.is_a?(Hash)
      raise InvalidConfigError, "config.version must be 1" unless data["version"] == 1

      command = data.dig("app", "command")
      raise InvalidConfigError, "app.command must be a non-empty array" unless command.is_a?(Array) && !command.empty?
      unless command.all? { |c| c.is_a?(String) || c.is_a?(Integer) }
        raise InvalidConfigError, "app.command entries must be strings"
      end

      mode = data.dig("preview", "mode")
      if mode && !%w[snapshot live].include?(mode)
        raise InvalidConfigError, "preview.mode must be 'snapshot' or 'live'"
      end

      Array(data.dig("app", "copy")).each do |path|
        if !path.is_a?(String) || path.start_with?("/") || path.split("/").include?("..")
          raise InvalidConfigError, "app.copy entries must be relative paths with no .. segments (got #{path.inspect})"
        end
      end
    end
  end
end

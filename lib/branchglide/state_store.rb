# frozen_string_literal: true

require "json"
require "fileutils"

module Branchglide
  # Persists preview/slot/tunnel state as JSON under .branchglide/state.json
  # in the main repo. Writes are atomic (write to temp file + rename) so a
  # crash mid-write never corrupts previously-good state.
  class StateStore
    def initialize(repo_root)
      @dir = File.join(repo_root, ".branchglide")
      @path = File.join(@dir, "state.json")
      FileUtils.mkdir_p(@dir)
      @data = load
    end

    def previews
      @data["previews"] ||= {}
    end

    def slots
      @data["slots"] ||= {}
    end

    def save
      tmp = "#{@path}.tmp.#{Process.pid}"
      File.write(tmp, JSON.pretty_generate(@data))
      File.rename(tmp, @path)
    end

    private

    def load
      return { "previews" => {}, "slots" => {} } unless File.exist?(@path)

      JSON.parse(File.read(@path))
    rescue JSON::ParserError
      { "previews" => {}, "slots" => {} }
    end
  end
end

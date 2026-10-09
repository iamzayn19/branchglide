# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"
require "branchglide"

module Branchglide
  module TestRepo
    # Builds a throwaway git repo with a main branch and a feature branch
    # that differ, so previews can be proven to serve different content.
    def self.build
      dir = Dir.mktmpdir("branchglide-test-")
      run(dir, %w[init -q -b main])
      run(dir, %w[config user.email test@example.com])
      run(dir, %w[config user.name Test])
      File.write(File.join(dir, "app.txt"), "main\n")
      run(dir, %w[add app.txt])
      run(dir, %w[commit -q -m init])
      run(dir, %w[checkout -q -b feature/checkout])
      File.write(File.join(dir, "app.txt"), "feature\n")
      run(dir, %w[add app.txt])
      run(dir, %w[commit -q -m feature])
      run(dir, %w[checkout -q main])
      dir
    end

    def self.run(dir, args)
      _out, err, status = Open3.capture3("git", *args, chdir: dir)
      raise "git #{args.join(' ')} failed: #{err}" unless status.success?
    end
  end
end

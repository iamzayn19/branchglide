# frozen_string_literal: true

require_relative "lib/branchglide/version"

Gem::Specification.new do |spec|
  spec.name = "branchglide"
  spec.version = Branchglide::VERSION
  spec.authors = ["Muhammad Zain Ul Abidin"]
  spec.email = ["iamzayn19@gmail.com"]

  spec.summary = "Preview any Git branch. Share it without deploying."
  spec.description = "Branchglide runs multiple Git branches independently using isolated " \
                      "worktrees, exposes previews through existing tunneling providers, and " \
                      "switches named preview slots between branches without restarting the " \
                      "public tunnel."
  spec.homepage = "https://github.com/iamzayn19/branchglide"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("{exe,lib}/**/*") + %w[README.md CHANGELOG.md LICENSE]
  spec.bindir = "exe"
  spec.executables = ["branchglide"]
  spec.require_paths = ["lib"]

  spec.add_dependency "psych", "~> 5.0"
end

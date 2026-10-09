# frozen_string_literal: true

module Branchglide
  class Error < StandardError; end

  class NotAGitRepositoryError < Error; end
  class ConfigNotFoundError < Error; end
  class InvalidConfigError < Error; end
  class BranchNotFoundError < Error; end
  class PreviewNotFoundError < Error; end
  class PreviewAlreadyExistsError < Error; end
  class SlotNotFoundError < Error; end
  class SlotAlreadyExistsError < Error; end
  class UnsafeTargetError < Error; end
  class ProcessStartError < Error; end
  class HealthCheckFailedError < Error; end
  class TunnelExecutableNotFoundError < Error; end
  class TunnelStartError < Error; end
  class PortExhaustedError < Error; end
end

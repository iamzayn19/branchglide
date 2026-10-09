# frozen_string_literal: true

require "test_helper"

module Branchglide
  class PortAllocatorTest < Minitest::Test
    def test_allocates_a_free_port_in_range
      allocator = PortAllocator.new(range: (3900..3910))
      port = allocator.allocate
      assert_includes(3900..3910, port)
    end

    def test_skips_reserved_ports
      allocator = PortAllocator.new(range: (3920..3922), reserved: [3920, 3921])
      assert_equal 3922, allocator.allocate
    end

    def test_raises_when_range_exhausted
      allocator = PortAllocator.new(range: (3930..3930), reserved: [3930])
      assert_raises(PortExhaustedError) { allocator.allocate }
    end
  end
end

# frozen_string_literal: true

module Branchglide
  module Tunnels
    # Interface every provider adapter implements, so ngrok/zrok/etc. can be
    # added later without touching CLI or share/unshare logic.
    class Base
      def start(_port)
        raise NotImplementedError
      end

      def stop
        raise NotImplementedError
      end

      def public_url
        raise NotImplementedError
      end

      def executable_available?
        raise NotImplementedError
      end
    end
  end
end

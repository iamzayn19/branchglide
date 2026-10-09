# frozen_string_literal: true

module Branchglide
  # Named, stable routing targets. A slot owns one PreviewRouter; `focus`
  # swaps the router's target to a different branch's preview only after
  # confirming that preview is healthy, and leaves the previous target in
  # place untouched if the health check fails.
  class SlotManager
    def initialize(state_store:, preview_manager:)
      @state = state_store
      @previews = preview_manager
      @routers = {}
    end

    def create(name, branch:)
      raise SlotAlreadyExistsError, "slot #{name} already exists" if @state.slots[name]
      raise PreviewNotFoundError, "no running preview for #{branch}" unless @previews.running?(branch)

      router = PreviewRouter.new
      router.start
      set_router_target(router, branch)
      @routers[name] = router

      @state.slots[name] = { "name" => name, "branch" => branch, "router_port" => router.port }
      @state.save
      @state.slots[name]
    end

    def remove(name)
      entry = @state.slots[name]
      raise SlotNotFoundError, "no such slot #{name}" unless entry

      @routers[name]&.stop
      @routers.delete(name)
      @state.slots.delete(name)
      @state.save
    end

    def list
      @state.slots.values
    end

    def get(name)
      @state.slots[name] or raise SlotNotFoundError, "no such slot #{name}"
    end

    # Atomically repoints a slot at a different branch's preview. The new
    # target is health-checked BEFORE the swap; on failure the slot keeps
    # routing to its previous (still-healthy) target.
    def focus(name, branch, health_timeout: 15)
      entry = get(name)
      raise PreviewNotFoundError, "no running preview for #{branch}" unless @previews.running?(branch)

      unless @previews.wait_healthy(branch, timeout: health_timeout)
        raise HealthCheckFailedError, "#{branch} did not become healthy within #{health_timeout}s; " \
                                       "slot #{name} still points at #{entry['branch']}"
      end

      router = router_for(name)
      set_router_target(router, branch)

      entry["branch"] = branch
      @state.save
      entry
    end

    private

    def router_for(name)
      @routers[name] ||= begin
        entry = get(name)
        router = PreviewRouter.new(port: entry["router_port"])
        router.start
        set_router_target(router, entry["branch"])
        router
      end
    end

    def set_router_target(router, branch)
      preview = @previews.status(branch)
      router.target = { host: "127.0.0.1", port: preview["port"] }
    end
  end
end

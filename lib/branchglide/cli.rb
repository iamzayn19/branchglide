# frozen_string_literal: true

require "json"

module Branchglide
  class CLI
    def self.run(argv)
      new.run(argv)
    end

    def run(argv)
      command, *rest = argv
      case command
      when nil, "-h", "--help" then help
      when "-v", "--version" then puts(Branchglide::VERSION)
      when "init" then init
      when "doctor" then doctor
      when "up" then up(rest)
      when "down" then down(rest)
      when "restart" then restart(rest)
      when "ls" then ls
      when "status" then status
      when "logs" then logs(rest)
      when "share" then share(rest)
      when "unshare" then unshare(rest)
      when "slot" then slot(rest)
      when "focus" then focus(rest)
      when "cleanup" then cleanup
      else
        warn("Unknown command: #{command}")
        help
        return 1
      end
      0
    rescue Error => e
      warn("Error: #{e.message}")
      1
    end

    private

    def help
      puts <<~HELP
        branchglide #{Branchglide::VERSION} -- preview any Git branch, share it without deploying.

        Usage:
          branchglide init
          branchglide doctor
          branchglide up <branch>
          branchglide down <branch>
          branchglide restart <branch>
          branchglide ls
          branchglide status
          branchglide logs <branch> [--follow]
          branchglide share <branch> | --slot <name>
          branchglide unshare <branch>
          branchglide slot create <name> --branch <branch>
          branchglide slot ls
          branchglide slot remove <name>
          branchglide focus <name> <branch>
          branchglide cleanup
      HELP
    end

    def init
      repo = Repository.discover
      path = File.join(repo.root, Config::FILE_NAME)
      if File.exist?(path)
        puts "#{Config::FILE_NAME} already exists."
        return
      end
      File.write(path, Config.default_yaml)
      puts "Wrote #{path}. Edit app.command for your project, then run `branchglide up <branch>`."
    end

    def doctor
      repo = Repository.discover
      puts "git repository: #{repo.root}"
      puts "config: #{File.exist?(File.join(repo.root, Config::FILE_NAME)) ? 'found' : 'missing (run `branchglide init`)'}"
      cloudflared = Tunnels::Cloudflare.new
      puts "cloudflared: #{cloudflared.executable_available? ? 'available' : 'not found on PATH'}"
    end

    def up(args)
      branch = args.first or raise Error, "usage: branchglide up <branch>"
      manager = preview_manager
      entry = manager.up(branch)
      puts "Preview for #{branch} started on port #{entry['port']} (commit #{entry['commit'][0, 8]})"
    end

    def down(args)
      branch = args.first or raise Error, "usage: branchglide down <branch>"
      preview_manager.down(branch)
      puts "Preview for #{branch} stopped and worktree removed."
    end

    def restart(args)
      branch = args.first or raise Error, "usage: branchglide restart <branch>"
      entry = preview_manager.restart(branch)
      puts "Preview for #{branch} restarted on port #{entry['port']}."
    end

    def ls
      rows = preview_manager.list
      if rows.empty?
        puts "No active previews."
        return
      end
      rows.each do |r|
        puts "#{r['branch']}\tport=#{r['port']}\tcommit=#{r['commit'][0, 8]}\tstarted=#{r['started_at']}"
      end
    end

    def status
      rows = preview_manager.list.map { |r| preview_manager.status(r["branch"]) }
      puts JSON.pretty_generate(rows)
    end

    def logs(args)
      branch = args.first or raise Error, "usage: branchglide logs <branch> [--follow]"
      if args.include?("--follow")
        entry = preview_manager.status(branch) or raise PreviewNotFoundError, "no preview for #{branch}"
        File.open(entry["log"]) do |f|
          f.seek(0, IO::SEEK_END)
          loop do
            line = f.gets
            line ? print(line) : sleep(0.5)
          end
        end
      else
        print preview_manager.logs(branch)
      end
    end

    def share(args)
      if args.first == "--slot"
        slot_name = args[1] or raise Error, "usage: branchglide share --slot <name>"
        entry = slot_manager.get(slot_name)
        tunnel = tunnel_for(slot_name)
        router_port = entry["router_port"]
        url = tunnel.start(router_port)
        warn_public(url)
      else
        branch = args.first or raise Error, "usage: branchglide share <branch>"
        entry = preview_manager.status(branch) or raise PreviewNotFoundError, "no preview for #{branch}"
        tunnel = tunnel_for(branch)
        url = tunnel.start(entry["port"])
        warn_public(url)
      end
    end

    def unshare(args)
      key = args.first or raise Error, "usage: branchglide unshare <branch>"
      tunnel_for(key).stop
      puts "Tunnel for #{key} stopped."
    end

    def slot(args)
      sub, *rest = args
      case sub
      when "create"
        name = rest.first or raise Error, "usage: branchglide slot create <name> --branch <branch>"
        branch = flag_value(rest, "--branch") or raise Error, "--branch is required"
        entry = slot_manager.create(name, branch: branch)
        puts "Slot #{name} created -> #{entry['branch']} (local router port #{entry['router_port']})"
      when "ls"
        slot_manager.list.each { |s| puts "#{s['name']}\t-> #{s['branch']}\tport=#{s['router_port']}" }
      when "remove"
        name = rest.first or raise Error, "usage: branchglide slot remove <name>"
        slot_manager.remove(name)
        puts "Slot #{name} removed."
      else
        raise Error, "usage: branchglide slot <create|ls|remove> ..."
      end
    end

    def focus(args)
      name, branch = args
      raise Error, "usage: branchglide focus <slot> <branch>" unless name && branch

      entry = slot_manager.focus(name, branch)
      puts "Slot #{name} now points at #{entry['branch']}."
    end

    def cleanup
      repo = Repository.discover
      repo.prune_worktrees
      puts "Pruned stale worktree records."
    end

    def warn_public(url)
      warn "WARNING: this exposes a local development server to the public internet."
      warn "The tunnel URL has no authentication unless your application enforces it."
      puts url
    end

    def flag_value(args, flag)
      idx = args.index(flag)
      return nil unless idx

      args[idx + 1]
    end

    def repository
      @repository ||= Repository.discover
    end

    def config
      @config ||= Config.load(repository.root)
    end

    def state_store
      @state_store ||= StateStore.new(repository.root)
    end

    def preview_manager
      @preview_manager ||= PreviewManager.new(repository: repository, config: config, state_store: state_store)
    end

    def slot_manager
      @slot_manager ||= SlotManager.new(state_store: state_store, preview_manager: preview_manager)
    end

    def tunnel_for(_key)
      Tunnels::Cloudflare.new
    end
  end
end

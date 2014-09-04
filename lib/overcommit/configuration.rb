module Overcommit
  # Stores configuration for Overcommit and the hooks it runs.
  class Configuration
    # Keys in `@hash` that do not represent a hook context. These must be
    # removed to determine the available contexts for the repo.
    NON_CONTEXT_KEYS = %w[
      plugin_directory
      verify_plugin_signatures
    ]

    # Creates a configuration from the given hash.
    def initialize(hash)
      @hash = ConfigurationValidator.new.validate(hash)
    end

    def ==(other)
      super || @hash == other.hash
    end
    alias_method :eql?, :==

    # Returns absolute path to the directory that external hook plugins should
    # be loaded from.
    def plugin_directory
      File.join(Overcommit::Utils.repo_root, @hash['plugin_directory'] || '.githooks')
    end

    def verify_plugin_signatures?
      @hash['verify_plugin_signatures'] != false
    end

    # Returns information on all hooks for the contexts with the given names.
    def all_hooks
      context_names = @hash.keys.reject { |k| NON_CONTEXT_KEYS.include? k }

      hooks = {}
      context_names.each do |context_name|
        hook_names = @hash[context_name].keys.reject { |name| name == 'ALL' }
        hooks[Overcommit::Utils.camel_case(context_name)] = hook_names
      end

      hooks
    end

    # Returns the built-in hooks that have been enabled for a hook type.
    def enabled_builtin_hooks(hook_context)
      @hash[hook_context.hook_class_name].keys.
        select { |hook_name| hook_name != 'ALL' }.
        select { |hook_name| built_in_hook?(hook_context, hook_name) }.
        select { |hook_name| hook_enabled?(hook_context, hook_name) }
    end

    # Returns a non-modifiable configuration for a hook.
    def for_hook(hook, hook_type = nil)
      unless hook_type
        components = hook.class.name.split('::')
        hook = components.last
        hook_type = components[-2]
      end

      # Merge hook configuration with special 'ALL' config
      smart_merge(@hash[hook_type]['ALL'], @hash[hook_type][hook] || {}).freeze
    end

    # Merges the given configuration with this one, returning a new
    # {Configuration}. The provided configuration will either add to or replace
    # any options defined in this configuration.
    def merge(config)
      self.class.new(smart_merge(@hash, config.hash))
    end

    # Applies additional configuration settings based on the provided
    # environment variables.
    def apply_environment!(hook_context, env)
      skipped_hooks = "#{env['SKIP']} #{env['SKIP_CHECKS']} #{env['SKIP_HOOKS']}".split(/[:, ]/)
      hook_type = hook_context.hook_class_name

      if skipped_hooks.include?('all') || skipped_hooks.include?('ALL')
        @hash[hook_type]['ALL']['skip'] = true
      else
        skipped_hooks.select { |hook_name| hook_exists?(hook_context, hook_name) }.
                      map { |hook_name| Overcommit::Utils.camel_case(hook_name) }.
                      each do |hook_name|
          @hash[hook_type][hook_name] ||= {}
          @hash[hook_type][hook_name]['skip'] = true
        end
      end
    end

    def hook_enabled?(hook_context, hook_name)
      hook_type = hook_context.hook_class_name
      individual_enabled = @hash[hook_type][hook_name]['enabled']
      return individual_enabled unless individual_enabled.nil?

      all_enabled = @hash[hook_type]['ALL']['enabled']
      return all_enabled unless all_enabled.nil?

      true
    end

  protected

    attr_reader :hash

    private

    def built_in_hook?(hook_context, hook_name)
      hook_name = Overcommit::Utils.snake_case(hook_name)

      File.exist?(File.join(OVERCOMMIT_HOME, 'lib', 'overcommit', 'hook',
                            hook_context.hook_type_name, "#{hook_name}.rb"))
    end

    def plugin_hook?(hook_context, hook_name)
      hook_name = Overcommit::Utils.snake_case(hook_name)

      File.exist?(File.join(plugin_directory,
                            hook_context.hook_type_name,
                            "#{hook_name}.rb"))
    end

    def hook_exists?(hook_context, hook_name)
      built_in_hook?(hook_context, hook_name) ||
        plugin_hook?(hook_context, hook_name)
    end

    def smart_merge(parent, child)
      parent.merge(child) do |_key, old, new|
        case old
        when Array
          old + Array(new)
        when Hash
          smart_merge(old, new)
        else
          new
        end
      end
    end
  end
end

# frozen_string_literal: true

require 'digest'

module Overcommit::HookLoader
  # Responsible for loading hooks that are specific to the repository Overcommit
  # is running in.
  class PluginHookLoader < Base
    def load_hooks
      check_for_modified_plugins if @config.verify_signatures?

      hooks = plugin_paths.map do |plugin_path|
        require plugin_path

        hook_name = Overcommit::Utils.camel_case(File.basename(plugin_path, '.rb'))
        create_hook(hook_name)
      end

      hooks + ad_hoc_hook_names.map do |hook_name|
        create_ad_hoc_hook(hook_name)
      end
    end

    def update_signatures
      log.success('No plugin signatures have changed') if modified_plugins.empty?

      modified_plugins.each do |plugin|
        plugin.update_signature!
        log.warning "Updated signature of plugin #{plugin.hook_name}"
      end
    end

    private

    def plugin_paths
      directory = File.join(@config.plugin_directory, @context.hook_type_name)
      Dir[File.join(directory, '*.rb')].sort
    end

    def plugin_hook_names
      plugin_paths.map do |path|
        Overcommit::Utils.camel_case(File.basename(path, '.rb'))
      end
    end

    def ad_hoc_hook_names
      @config.enabled_ad_hoc_hooks(@context)
    end

    def modified_plugins
      (plugin_hook_names + ad_hoc_hook_names).
        map { |hook_name| Overcommit::HookSigner.new(hook_name, @config, @context) }.
        select(&:signature_changed?)
    end

    def check_for_modified_plugins
      return if modified_plugins.empty?

      log.bold_warning "The following #{@context.hook_script_name} plugins " \
                       'have been added, changed, or had their configuration modified:'
      log.newline

      modified_plugins.each do |signer|
        log.warning " * #{signer.hook_name} in #{signer.hook_path}"
      end

      log.newline
      log.bold_warning 'You should verify the changes and then run:'
      log.newline
      log.warning "overcommit --sign #{@context.hook_script_name}"
      log.newline
      log.log "For more information, see #{Overcommit::REPO_URL}#security"

      raise Overcommit::Exceptions::InvalidHookSignature
    end

    def create_git_hook_class(hook_base)
      # Implement a simple class that executes the command and returns pass/fail
      # based on the exit status
      Class.new(hook_base) do
        def run
          result = @context.execute_hook(command)
          if result.success?
            :pass
          else
            [:fail, result.stdout + result.stderr]
          end
        end
      end
    end

    def create_ad_hoc_hook(hook_name)
      hook_module = Overcommit::Hook.const_get(@context.hook_class_name)
      hook_base = hook_module.const_get('Base')

      hook_config = @config.for_hook(hook_name, @context.hook_class_name)
      hook_class =
        if hook_config['ad_hoc']
          create_line_aware_command_hook_class(hook_base)
        else
          create_git_hook_class(hook_base)
        end

      # Only to avoid warnings in unit tests...:
      if hook_module.const_defined?(hook_name)
        return hook_module.const_get(hook_name).new(@config, @context)
      end

      hook_module.const_set(hook_name, hook_class).new(@config, @context)
    rescue LoadError, NameError => e
      raise Overcommit::Exceptions::HookLoadError,
            "Unable to load hook '#{hook_name}': #{e}",
            e.backtrace
    end
  end
end

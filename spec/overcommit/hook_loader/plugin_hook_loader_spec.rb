# frozen_string_literal: true

require 'spec_helper'

describe 'ad-hoc pre-commit hook' do
  subject do
    hook_loader = Overcommit::HookLoader::PluginHookLoader.new(
      config,
      context,
      Overcommit::Logger.new(STDOUT)
    )
    hooks = hook_loader.load_hooks
    hooks.find { |h| h.name == hook_name }
  end
  let(:config) do
    config = Overcommit::Configuration.new(
      YAML.safe_load(config_contents, [Regexp]), {
        validate: false
      }
    )
    Overcommit::ConfigurationLoader.default_configuration.merge(config)
  end
  let(:context) do
    empty_stdin = File.open(File::NULL) # pre-commit hooks don't take input
    context = Overcommit::HookContext.create('pre-commit', config, applicable_files, empty_stdin)
    context
  end

  around do |example|
    repo do
      example.run
    end
  end

  describe 'if not line-aware' do
    let(:config_contents) do
      <<-'YML'
        PreCommit:
          FooGitHook:
            enabled: true
            command: "foocmd"
      YML
    end
    let(:hook_name) { 'FooGitHook' }
    let(:applicable_files) { nil }

    before do
      context.stub(:execute_hook).with(%w[foocmd]).
        and_return(result)
    end

    context 'when command succeeds' do
      let(:result) do
        double(success?: true, stdout: '')
      end

      it { should pass }
    end

    context 'when command fails' do
      let(:result) do
        double(success?: false, stdout: '', stderr: '')
      end

      it { should fail_hook }
    end
  end

  describe 'if line-aware' do
    let(:config_contents) do
      <<-'YML'
        PreCommit:
          FooLint:
            enabled: true
            command: ["foo", "lint"]
            ad_hoc:
              message_pattern: !ruby/regexp /^(?<file>[^:]+):(?<line>[0-9]+):(?<type>[^ ]+)/
              warning_message_type_pattern: warning
            flags:
            - "--format=emacs"
            include: '**/*.foo'
          FooLintDefault:
            enabled: true
            command: ["foo", "lint"]
            ad_hoc:
              warning_message_type_pattern: warning
            flags:
            - "--format=emacs"
            include: '**/*.foo'
          FooLintDefaultNoWarnings:
            enabled: true
            command: ["foo", "lint"]
            ad_hoc:
            flags:
            - "--format=emacs"
            include: '**/*.foo'
      YML
    end
    let(:hook_name) { 'FooLint' }
    let(:applicable_files) { %w[file.foo] }

    before do
      subject.stub(:applicable_files).and_return(applicable_files)
      subject.stub(:execute).with(%w[foo lint --format=emacs], args: applicable_files).
        and_return(result)
    end

    context 'when command succeeds' do
      let(:result) do
        double(success?: true, stdout: '')
      end

      it { should pass }
    end

    context 'when command fails with empty stdout' do
      let(:result) do
        double(success?: false, stdout: '', stderr: '')
      end

      it { should pass }
    end

    context 'when command fails with some warning message' do
      let(:result) do
        double(
          success?: false,
          stdout: "A:1:warning...\n",
          stderr: ''
        )
      end

      it { should warn }
    end

    context 'when command fails with some error message' do
      let(:result) do
        double(
          success?: false,
          stdout: "A:1:???\n",
          stderr: ''
        )
      end

      it { should fail_hook }
    end

    describe '(using default pattern)' do
      let(:hook_name) { 'FooLintDefault' }

      context 'when command fails with some warning message' do
        let(:result) do
          double(
            success?: false,
            stdout: <<-MSG,
B:1: warning: ???
            MSG
            stderr: ''
          )
        end

        it { should warn }
      end

      context 'when command fails with some error message' do
        let(:result) do
          double(
            success?: false,
            stdout: <<-MSG,
A:1:80: error
            MSG
            stderr: ''
          )
        end

        it { should fail_hook }
      end
    end

    describe '(using defaults)' do
      let(:hook_name) { 'FooLintDefaultNoWarnings' }

      context 'when command fails with some messages' do
        let(:result) do
          double(
            success?: false,
            stdout: <<-MSG,
A:1:80: error
B:1: warning: ???
            MSG
            stderr: ''
          )
        end

        it { should fail_hook }
      end
    end
  end
end

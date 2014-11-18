require 'spec_helper'
require 'overcommit/cli'
require 'overcommit/hook_context/run_all'

describe Overcommit::CLI do
  describe '#run' do
    let(:logger) { Overcommit::Logger.silent }
    let(:cli) { described_class.new(arguments, logger) }
    subject { cli.run }

    before do
      Overcommit::Utils.stub(:repo_root).and_return('current-dir')
    end

    context 'with no arguments' do
      let(:arguments) { [] }

      it 'attempts to install in the current directory' do
        Overcommit::Installer.any_instance.
                              should_receive(:run).
                              with('current-dir',
                                   hash_including(:action => :install))
        subject
      end
    end

    context 'with the --list-hooks option specified' do
      let(:arguments) { ['--list-hooks'] }
      let(:contexts) do
        Overcommit::ConfigurationLoader.load_repo_config.all_hooks.keys
      end

      before { cli.stub(:halt) }

      it 'prints the installed hooks' do
        logger.should_receive(:log).at_least(:once)
        subject
      end
    end

    context 'with the uninstall switch specified' do
      let(:arguments) { ['--uninstall'] }

      it 'uninstalls hooks from the current directory' do
        Overcommit::Installer.any_instance.
                              should_receive(:run).
                              with('current-dir',
                                   hash_including(:action => :uninstall))
        subject
      end

      context 'and an explicit target' do
        let(:arguments) { super() + ['target-dir'] }

        it 'uninstalls hooks from the target directory' do
          Overcommit::Installer.any_instance.
                                should_receive(:run).
                                with('target-dir',
                                     hash_including(:action => :uninstall))
          subject
        end
      end
    end

    context 'with the install switch specified' do
      let(:arguments) { ['--install'] }

      it 'installs hooks into the current directory' do
        Overcommit::Installer.any_instance.
                              should_receive(:run).
                              with('current-dir',
                                   hash_including(:action => :install))
        subject
      end

      context 'and an explicit target' do
        let(:arguments) { super() + ['target-dir'] }

        it 'installs hooks from the target directory' do
          Overcommit::Installer.any_instance.
                                should_receive(:run).
                                with('target-dir',
                                     hash_including(:action => :install))
          subject
        end
      end
    end

    context 'with the template directory switch specified' do
      let(:arguments) { ['--template-dir'] }

      before do
        cli.stub(:halt)
      end

      it 'prints the location of the template directory' do
        capture_stdout { subject }.chomp.should end_with 'template-dir'
      end
    end

    context 'with the run switch specified' do
      let(:arguments) { ['--run'] }
      let(:config) do
        Overcommit::ConfigurationLoader.load_repo_config
      end

      before do
        cli.stub(:halt)
      end

      it 'creates a hookrunner with the run-all context' do
        Overcommit::HookRunner.should_receive(:new).
                               with(config,
                                    logger,
                                    instance_of(Overcommit::HookContext::RunAll),
                                    nil,
                                    instance_of(Overcommit::Printer)).
                               and_call_original
        subject
      end

      it 'runs the hookrunner' do
        Overcommit::HookRunner.any_instance.should_receive(:run)
        subject
      end
    end
  end
end

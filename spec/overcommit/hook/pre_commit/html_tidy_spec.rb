require 'spec_helper'

describe Overcommit::Hook::PreCommit::HtmlTidy do
  let(:config)  { Overcommit::ConfigurationLoader.default_configuration }
  let(:context) { double('context') }
  subject { described_class.new(config, context) }

  before do
    subject.stub(:applicable_files).and_return(%w[file1.html file2.html])
  end

  context 'when tidy exits successfully' do
    let(:result) { double('result') }

    before do
      result.stub(:success?).and_return(true)
      subject.stub(:execute).and_return(result)
    end

    context 'with no errors' do
      before do
        result.stub(:stderr).and_return('')
      end

      it { should pass }
    end
  end

  context 'when tidy exits unsuccessfully' do
    let(:result) { double('result') }

    before do
      result.stub(:success?).and_return(false)
      subject.stub(:execute).and_return(result)
    end

    context 'and it reports a warning' do
      before do
        result.stub(:stderr).and_return([
          'line 4 column 24 - Warning: <html> proprietary attribute "class"'
        ].join("\n"))

        subject.stub(:modified_lines_in_file).and_return([2, 3])
      end

      it { should warn }
    end

    context 'and it reports an error' do
      before do
        result.stub(:stderr).and_return([
          'line 1 column 1 - Error: <foo> is not recognized!'
        ].join("\n"))

        subject.stub(:modified_lines_in_file).and_return([1, 2])
      end

      it { should fail_hook }
    end
  end
end

module Overcommit::Hook::PreCommit
  # Runs `semistandard` against any modified JavaScript files.
  class SemiStandard < Base
    def run
      result = execute(command + applicable_files)
      output = result.stderr.chomp
      return :pass if result.success? && output.empty?

      # example message:
      #   path/to/file.js:1:1: Error message (ruleName)
      extract_messages(
        output.split("\n")[1..-1], # ignore header line
        /^(?<file>[^:]+):(?<line>\d+)/
      )
    end
  end
end

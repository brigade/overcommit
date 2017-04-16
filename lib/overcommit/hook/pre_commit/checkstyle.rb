module Overcommit::Hook::PreCommit
  # Runs `checkstyle` against any modified Java files.
  class Checkstyle < Base
    MESSAGE_REGEX = /^(?<file>[^:]+):(?<line>\d+)/

    def run
      result = execute(command + applicable_files)
      output = result.stdout.chomp
      return :pass if result.success?

      # example message:
      #   path/to/file.java:3:5: Error message
      extract_messages(
        output.split("\n").grep(MESSAGE_REGEX),
        MESSAGE_REGEX
      )
    end
  end
end

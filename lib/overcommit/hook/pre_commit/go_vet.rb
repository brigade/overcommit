module Overcommit::Hook::PreCommit
  # Runs `go vet` against any modified Golang files.
  class GoVet < Base
    def run
      result = execute(command + applicable_files)
      return :pass if result.success?

      if result.stderr =~ /no such tool "vet"/
        return :fail, "`go tool vet` is not installed#{install_command_prompt}"
      end

      # example message:
      #   path/to/file.go:7: Error message
      extract_messages(
        result.stderr.split("\n"),
        /^(?<file>[^:]+):(?<line>\d+)/
      )
    end
  end
end

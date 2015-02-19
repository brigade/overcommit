module Overcommit::Hook::PreCommit
  # Runs `eslint` against any modified JavaScript files.
  class EsLint < Base
    def run
      result = execute(command + applicable_files)
      output = result.stdout

      return :pass if output.empty?

      [:fail, output]
    end
  end
end

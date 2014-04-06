module Overcommit::Hook::PreCommit
  # Runs `brakeman` against any modified Ruby/Rails files.
  class Brakeman < Base
    def run
      unless in_path?('brakeman')
        return :warn, 'Run `gem install brakeman`'
      end

      result = execute(%w[brakeman --exit-on-warn --quiet --summary])

      if result.success?
        :good
      else
        [ :bad, result.stdout ]
      end
    end
  end
end

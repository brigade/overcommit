# frozen_string_literal: true

module Overcommit::Utils
  # Utility to process messages
  module MessagesUtils
    class << self
      # Extract file, line number, and type of message from an error/warning
      # messages in output.
      #
      # Assumes each element of `output` is a separate error/warning with all
      # information necessary to identify it.
      #
      # @param output_messages [Array<String>] unprocessed error/warning messages
      # @param regex [Regexp] regular expression defining `file`, `line` and
      #   `type` capture groups used to extract file locations and error/warning
      #   type from each line of output
      # @param type_categorizer [Proc] function executed against the `type`
      #   capture group to convert it to a `:warning` or `:error` symbol. Assumes
      #   `:error` if `nil`.
      # @raise [Overcommit::Exceptions::MessageProcessingError] line of output did
      #   not match regex
      # @return [Array<Message>]
      def extract_messages(output_messages, regex, type_categorizer = nil)
        output_messages.map.with_index do |message, index|
          unless match = message.match(regex)
            raise Overcommit::Exceptions::MessageProcessingError,
                  'Unexpected output: unable to determine line number or type ' \
                  "of error/warning for output:\n" \
                  "#{output_messages[index..-1].join("\n")}"
          end

          file = extract_file(match, message)
          line = extract_line(match, message) if match.names.include?('line') && match[:line]
          type = extract_type(match, message, type_categorizer)

          Overcommit::Hook::Message.new(type, file, line, message)
        end
      end

      def create_type_categorizer(warning_pattern)
        return nil if warning_pattern.nil?

        lambda do |type|
          type.include?(warning_pattern) ? :warning : :error
        end
      end

      private

      def extract_file(match, message)
        return unless match.names.include?('file')

        if match[:file].to_s.empty?
          raise Overcommit::Exceptions::MessageProcessingError,
                "Unexpected output: no file found in '#{message}'"
        end

        match[:file]
      end

      def extract_line(match, message)
        return unless match.names.include?('line')

        Integer(match[:line])
      rescue ArgumentError, TypeError
        raise Overcommit::Exceptions::MessageProcessingError,
              "Unexpected output: invalid line number found in '#{message}'"
      end

      def extract_type(match, message, type_categorizer)
        if type_categorizer
          type_match = match.names.include?('type') ? match[:type] : nil
          type = type_categorizer.call(type_match)
          unless Overcommit::Hook::MESSAGE_TYPES.include?(type)
            raise Overcommit::Exceptions::MessageProcessingError,
                  "Invalid message type '#{type}' for '#{message}': must " \
                  "be one of #{Overcommit::Hook::MESSAGE_TYPES.inspect}"
          end
          type
        else
          :error # Assume error since no categorizer was defined
        end
      end
    end
  end
end

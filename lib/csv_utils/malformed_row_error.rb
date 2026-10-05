# frozen_string_literal: true

module CSVUtils
  # A CSV::MalformedCSVError with the physical line the bad row starts on, rather than CSV's row count,
  # and the row read before it.
  class MalformedRowError < CSV::MalformedCSVError
    include Error

    # @return [Array<String>, nil] the last row read successfully
    attr_reader :prev_row

    # @param message [String] CSV's message without its "in line N." suffix
    # @param line_number [Integer] physical line the bad row starts on
    # @param prev_row [Array<String>, nil]
    def initialize(message, line_number, prev_row)
      @prev_row = prev_row
      super(message, line_number)
    end
  end
end

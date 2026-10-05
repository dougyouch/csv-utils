# frozen_string_literal: true

module CSVUtils
  # Included in every exception this library raises, so `rescue CSVUtils::Error` catches all of them.
  # Each exception also subclasses the error Ruby or CSV would raise, so existing rescues keep working.
  module Error
  end
end

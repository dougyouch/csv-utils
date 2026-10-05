# frozen_string_literal: true

module CSVUtils
  # Copies a CSV file to a new one with extra columns added to every row.
  #
  # @example
  #   extender = CSVUtils::CSVExtender.new('input.csv', 'output.csv')
  #   extender.append(['name_length']) { |row, headers| [row[headers.index('name')].size] }
  class CSVExtender
    # @param src_csv [String, CSV, #shift] path or CSV to read; paths are opened and closed by the extender
    # @param dest_csv [String, CSV, #<<] path or CSV to write
    # @param csv_options [Hash] options passed to CSV.open for paths; the source is read with its :encoding,
    #   'bom|utf-8' by default, and the output written in the encoding values were decoded to (see {EncodingOptions})
    def initialize(src_csv, dest_csv, csv_options = {})
      @src_csv = CSVUtils::CSVWrapper.new(src_csv, 'rb', EncodingOptions.read(csv_options))
      @dest_csv = CSVUtils::CSVWrapper.new(dest_csv, 'wb', EncodingOptions.write(csv_options))
    end

    # Appends columns one row at a time, then closes the files it opened.
    # @param additional_headers [Array<String>, nil] headers to add; nil when the source has no header row
    # @yieldparam row [Array<String>] the source row
    # @yieldparam headers [Array<String>, nil] the source headers
    # @yieldreturn [Array] values to append to the row
    # @return [void]
    def append(additional_headers)
      process(additional_headers) do |current_headers|
        while (row = @src_csv.shift)
          additional_columns = yield row, current_headers
          @dest_csv << (row + additional_columns)
        end
      end
    end

    # Appends columns a batch of rows at a time, for lookups that are cheaper in bulk
    # (ex: one database query per batch), then closes the files it opened.
    # @param additional_headers [Array<String>, nil] headers to add; nil when the source has no header row
    # @param batch_size [Integer] rows per batch
    # @yieldparam batch [Array<Array<String>>] the source rows
    # @yieldparam headers [Array<String>, nil] the source headers
    # @yieldreturn [Array<Array>] values to append, one array per row in the batch
    # @return [void]
    def append_in_batches(additional_headers, batch_size = 1_000)
      process(additional_headers) do |current_headers|
        batch = []

        process_batch_proc = proc do
          additional_rows = yield batch, current_headers

          batch.each_with_index do |row, idx|
            @dest_csv << (row + additional_rows[idx])
          end

          batch = []
        end

        while (row = @src_csv.shift)
          batch << row

          process_batch_proc.call if batch.size >= batch_size
        end

        process_batch_proc.call if batch.size.positive?
      end
    end

    private

    def process(additional_headers)
      current_headers = append_headers(additional_headers)

      yield current_headers
    ensure
      close
    end

    def close
      @src_csv.close
      @dest_csv.close
    end

    def append_headers(additional_headers)
      return nil unless additional_headers

      current_headers = @src_csv.shift
      @dest_csv << (current_headers + additional_headers)
      current_headers
    end
  end
end

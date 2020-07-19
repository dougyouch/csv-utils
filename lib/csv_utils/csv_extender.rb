# Utility class for appending data to a csv file.
class CSVUtils::CSVExtender
  def initialize(src_csv, dest_csv, csv_options = {})
    @src_csv = CSVUtils::CSVWrapper.new(src_csv, 'rb', csv_options)
    @dest_csv = CSVUtils::CSVWrapper.new(dest_csv, 'wb', csv_options)
  end

  def append(additional_headers)
    process(additional_headers) do |current_headers|
      while (row = @src_csv.shift)
        additional_columns = yield row, current_headers
        @dest_csv << (row + additional_columns)
      end
    end
  end

  def append_in_batches(additional_headers, batch_size = 1_000)
    process(additional_headers) do |current_headers|
      batch = []

      process_batch_proc = Proc.new do
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

      process_batch_proc.call if batch.size > 0
    end
  end

  private

  def process(additional_headers)
    current_headers = append_headers(additional_headers)

    yield current_headers

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

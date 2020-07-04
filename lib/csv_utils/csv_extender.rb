# Utility class for appending data to a csv file.
class CSVUtils::CSVExtender
  attr_reader :csv_file,
              :new_csv_file,
              :csv_options

  def initialize(csv_file, new_csv_file, csv_options = {})
    @csv_file = csv_file
    @new_csv_file = new_csv_file
    @csv_options = csv_options
  end

  def append(additional_headers)
    process(additional_headers) do |current_headers|
      while (row = src.shift)
        additional_columns = yield row, current_headers
        dest << (row + additional_columns)
      end
    end
  end

  def append_in_batches(additional_headers, batch_size = 1_000)
    process(additional_headers) do |current_headers|
      batch = []

      process_batch_proc = Proc.new do
        additional_rows = yield batch, current_headers

        batch.each_with_index do |row, idx|
          dest << (row + additional_rows[idx])
        end

        batch = []
      end

      while (row = src.shift)
        batch << row

        process_batch_proc.call if batch.size >= batch_size
      end

      process_batch_proc.call if batch.size > 0
    end
  end

  def process(additional_headers)
    current_headers = append_headers(additional_headers)

    yield current_headers

    close
  end

  def src
    @src ||= CSV.open(csv_file, 'rb', csv_options)
  end

  def dest
    @dest ||= CSV.open(new_csv_file, 'wb', csv_options)
  end

  def close
    src.close
    dest.close
  end

  private

  def append_headers(additional_headers)
    return nil unless additional_headers

    current_headers = src.shift
    dest << (current_headers + additional_headers)
    current_headers
  end
end

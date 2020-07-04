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
    open(additional_headers) do |src, dest, headers|
      while (row = src.shift)
        additional_columns = yield row, headers
        dest << (row + additional_columns)
      end
    end
  end

  def append_in_batches(additional_headers, batch_size = 1_000)
    open(additional_headers) do |src, dest, headers|
      batch = []

      process_batch_proc = Proc.new do
        additional_rows = yield batch, headers

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

  def open(additional_headers)
    CSV.open(csv_file, 'rb', csv_options) do |src|
      CSV.open(new_csv_file, 'wb', csv_options) do |dest|
        headers = append_headers(src, dest, additional_headers)

        yield src, dest, headers
      end
    end
  end

  private

  def append_headers(src, dest, additional_headers)
    return nil unless additional_headers

    headers = src.shift
    dest << (headers + additional_headers)
    headers
  end
end

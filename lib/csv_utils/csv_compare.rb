# frozen_string_literal: true

module CSVUtils
  # Compares two CSV files sorted on the same key and yields what it takes to make the secondary file
  # match the primary one: records to create, update or delete. Sort both files first, {CSVSort} can do it.
  #
  # Updates are only reported for the update_comparison_columns; subclass and override update_row? for other rules.
  #
  # @example
  #   comparer = CSVUtils::CSVCompare.new('primary.csv', ['updated_at']) { |src, dest| src['id'].to_i <=> dest['id'].to_i }
  #   comparer.compare('secondary.csv') { |action, record| puts "#{action} #{record['id']}" }
  class CSVCompare
    # @return [String] path of the source of truth
    attr_reader :primary_data_file
    # @return [Array<String>, nil] columns, present in both files, that trigger an update when they differ
    #   (ex: updated_at, a timestamp or a hash of the row)
    attr_reader :update_comparison_columns
    # @return [Proc] compares the key columns of a primary and a secondary record, returning -1, 0 or 1
    attr_reader :compare_proc
    # @return [Hash] options passed to CSV.open for both files
    attr_reader :csv_options

    # @param primary_data_file [String] path of the source of truth
    # @param update_comparison_columns [Array<String>, nil] columns compared on matching records;
    #   without them no updates are yielded
    # @param csv_options [Hash] options passed to CSV.open for both files, ex: col_sep: "\t",
    #   or encoding: 'BINARY' to read bytes that aren't valid UTF-8
    # @yieldparam src [Hash{String => String}] record from the primary file
    # @yieldparam dest [Hash{String => String}] record from the secondary file
    # @yieldreturn [Integer] negative, 0 or positive like <=>, using the same order both files are sorted by
    def initialize(primary_data_file, update_comparison_columns = nil, csv_options = {}, &block)
      @primary_data_file = primary_data_file
      @update_comparison_columns = update_comparison_columns
      @csv_options = csv_options
      @compare_proc = block
    end

    # Walks both files and yields each difference.
    # @param secondary_data_file [String] path of the file to bring in line with the primary file
    # @yieldparam action [Symbol] :create (only in the primary file), :update (in both, with changed
    #   update_comparison_columns) or :delete (only in the secondary file)
    # @yieldparam record [Hash{String => String}] the primary record for :create and :update,
    #   the secondary record for :delete
    # @return [void]
    def compare(secondary_data_file, &)
      open_csv(primary_data_file) do |src, src_headers|
        open_csv(secondary_data_file) do |dest, dest_headers|
          compare_records(src, src_headers, dest, dest_headers, &)
        end
      end
    end

    private

    # walks both sorted files at once, advancing whichever side is behind
    def compare_records(src, src_headers, dest, dest_headers)
      src_record = next_record(src_headers, src)
      dest_record = next_record(dest_headers, dest)

      while src_record || dest_record
        case record_action(src_record, dest_record)
        when :create
          yield :create, src_record
          src_record = next_record(src_headers, src)
        when :delete
          yield :delete, dest_record
          dest_record = next_record(dest_headers, dest)
        else
          yield :update, src_record if update_row?(src_record, dest_record)
          src_record = next_record(src_headers, src)
          dest_record = next_record(dest_headers, dest)
        end
      end
    end

    def record_action(src_record, dest_record)
      return :delete unless src_record
      return :create unless dest_record

      result = compare_proc.call(src_record, dest_record)
      if result.zero?
        :match
      elsif result.positive?
        :delete
      else
        :create
      end
    end

    def open_csv(file)
      csv = CSV.open(file, 'rb', **csv_options)
      yield csv, read_headers(csv)
    ensure
      csv&.close
    end

    def read_headers(csv)
      headers = csv.shift || []
      headers[0] = ByteOrderMark.strip(headers[0]) if headers[0]
      headers
    end

    def next_record(headers, csv)
      return unless (row = csv.shift)

      headers.zip(row).to_h
    end

    def update_row?(src_record, dest_record)
      return false unless update_comparison_columns

      update_comparison_columns.any? do |column_name|
        src_record[column_name] != dest_record[column_name]
      end
    end
  end
end

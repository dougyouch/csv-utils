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
    #   or encoding: 'BINARY' to read bytes that aren't valid UTF-8; the :encoding defaults to 'bom|utf-8'
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
    # @param check_order [Boolean] raise when a file isn't sorted the way the compare block expects, by comparing
    #   each record with the one before it in the same file. A file is only checked when the block compares its
    #   first record equal to itself, so a block written for different headers in each file skips the check.
    # @yieldparam action [Symbol] :create (only in the primary file), :update (in both, with changed
    #   update_comparison_columns) or :delete (only in the secondary file)
    # @yieldparam record [CSVIterator::RowWrapper] the primary record for :create and :update, the secondary
    #   record for :delete; a Hash of header to value that knows the line it starts on
    # @return [void]
    # @raise [HeaderNotFoundError] when an update_comparison_column isn't in one of the files
    # @raise [UnsortedFileError] when check_order finds a record out of order
    def compare(secondary_data_file, check_order: true, &)
      @check_order = check_order
      open_csv(primary_data_file) do |src|
        open_csv(secondary_data_file) do |dest|
          compare_records(src, dest, &)
        end
      end
    end

    private

    # walks both sorted files at once, advancing whichever side is behind
    def compare_records(src, dest)
      src_record = next_record(src)
      dest_record = next_record(dest)

      while src_record || dest_record
        case record_action(src_record, dest_record)
        when :create
          yield :create, src_record
          src_record = next_record(src, src_record)
        when :delete
          yield :delete, dest_record
          dest_record = next_record(dest, dest_record)
        else
          yield :update, src_record if update_row?(src_record, dest_record)
          src_record = next_record(src, src_record)
          dest_record = next_record(dest, dest_record)
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

    # yields the file's path, reader, headers and whether its order is checked, decided at its first record
    def open_csv(file)
      csv = CSV.open(file, 'rb', **EncodingOptions.read(csv_options))
      reader = RowReader.new(csv)
      headers = reader.shift || []
      check_update_comparison_columns(headers)
      yield({ file: file, reader: reader, headers: headers, check_order: nil })
    ensure
      csv&.close
    end

    def check_update_comparison_columns(headers)
      missing = (update_comparison_columns || []) - headers
      raise HeaderNotFoundError.new(missing.first, headers) unless missing.empty?
    end

    def next_record(source, previous_record = nil)
      return unless (row = source[:reader].shift)

      record = CSVIterator::RowWrapper.create(source[:headers], row, source[:reader].lineno)
      source[:check_order] = @check_order && compare_proc.call(record, record).zero? if source[:check_order].nil?
      check_order(source[:file], previous_record, record) if previous_record && source[:check_order]
      record
    end

    def check_order(file, previous_record, record)
      raise UnsortedFileError.new(file, record.lineno) if compare_proc.call(previous_record, record).positive?
    end

    def update_row?(src_record, dest_record)
      return false unless update_comparison_columns

      update_comparison_columns.any? do |column_name|
        src_record[column_name] != dest_record[column_name]
      end
    end
  end
end

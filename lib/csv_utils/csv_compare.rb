# frozen_string_literal: true

# CSVUtils::CSVCompare purpose is to determine which rows in the secondary_data_file need to be created, deleted or updated
# **requires both CSV files to be sorted on the same columns, CSVUtils::CSVSort can accomplish this
# In order to receive updates, update_comparison_columns must configured or use inheritance and change the update_row? method
module CSVUtils
  class CSVCompare
    # primary_data_file is the source of truth
    # compare_proc used to compare the id column(s)
    # update_comparison_columns column(s) to compare for equality, ex: updated_at, timestamp, hash
    #  caveat: update_comparison_columns need to be in both csv files
    attr_reader :primary_data_file,
                :update_comparison_columns,
                :compare_proc

    def initialize(primary_data_file, update_comparison_columns = nil, &block)
      @primary_data_file = primary_data_file
      @update_comparison_columns = update_comparison_columns
      @compare_proc = block
    end

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
      csv = CSV.open(file, 'rb')
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

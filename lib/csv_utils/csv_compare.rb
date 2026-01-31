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

    # rubocop:disable Metrics/MethodLength
    def compare(secondary_data_file)
      src = CSV.open(primary_data_file, 'rb')
      begin
        src_headers = src.shift
        strip_bom!(src_headers[0])
        dest = CSV.open(secondary_data_file, 'rb')
        begin
          dest_headers = dest.shift
          strip_bom!(dest_headers[0])

          read_next_src = true
          read_next_dest = true

          while !src.eof? || !dest.eof?
            src_record = next_record_from_file(src_headers, src) if read_next_src
            dest_record = next_record_from_file(dest_headers, dest) if read_next_dest

            if !src_record
              read_next_src = false
              read_next_dest = true
              yield :delete, dest_record
            elsif !dest_record
              read_next_src = true
              read_next_dest = false
              yield :create, src_record
            elsif compare_proc.call(src_record, dest_record).zero?
              read_next_src = true
              read_next_dest = true
              yield(:update, src_record) if update_row?(src_record, dest_record)
            elsif compare_proc.call(src_record, dest_record).positive?
              read_next_src = false
              read_next_dest = true
              yield :delete, dest_record
            else
              read_next_src = true
              read_next_dest = false
              yield :create, src_record
            end
          end
        ensure
          dest.close
        end
      ensure
        src.close
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    def next_record_from_file(headers, file)
      return nil if file.eof?

      headers.zip(file.shift).to_h
    end

    def update_row?(src_record, dest_record)
      return false unless update_comparison_columns

      update_comparison_columns.each do |column_name|
        return true unless src_record[column_name] == dest_record[column_name]
      end

      false
    end

    def strip_bom!(col)
      col.sub!((+"\xEF\xBB\xBF").force_encoding('ASCII-8BIT'), '')
    end
  end
end

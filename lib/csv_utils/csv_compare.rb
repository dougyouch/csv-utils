# frozen_string_literal: true
require 'shellwords'

class CSVUtils::CSVCompare
  include CommandLineHelpers

  attr_reader :primary_data_file,
              :compare_proc

  def initialize(primary_data_file, &block)
    @primary_data_file = primary_data_file
    @compare_proc = block
  end

  def compare(secondary_data_file)
    src = CSV.open(primary_data_file)
    src_headers = src.shift
    dest = CSV.open(secondary_data_file)
    dest_headers = dest.shift

    read_next_src = true
    read_next_dest = true

    while(!src.eof? || !dest.eof?)
      src_record = next_record_from_file(src_headers, src) if read_next_src
      dest_record = next_record_from_file(dest_headers, dest) if read_next_dest

      if ! src_record
        read_next_src = false
        read_next_dest = true

        yield :delete, dest_record
      elsif ! dest_record
        read_next_src = true
        read_next_dest = false

        yield :create, src_record
      elsif compare_proc.call(src_record, dest_record) == 0
        read_next_src = true
        read_next_dest = true

        unless src_record['timestamp'] == dest_record['timestamp']
          yield :update, src_record
        end
      elsif compare_proc.call(src_record, dest_record) > 0
        read_next_src = false
        read_next_dest = true

        yield :delete, dest_record
      else
        read_next_src = true
        read_next_dest = false

        yield :create, src_record
      end
    end

    src.close
    dest.close
  end

  private

  def next_record_from_file(headers, file)
    return nil if file.eof?

    Hash[headers.zip(file.shift)]
  end
end

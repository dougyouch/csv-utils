# frozen_string_literal: true

require 'fileutils'

# Utility class for sorting the rows for a csv file
module CSVUtils
  class CSVSort
    attr_reader :csv_file,
                :new_csv_file,
                :has_headers,
                :csv_options,
                :headers

    def initialize(csv_file, new_csv_file, has_headers = true, csv_options = {})
      @csv_file = csv_file
      @new_csv_file = new_csv_file
      @has_headers = has_headers
      @csv_options = csv_options
      @csv_part_files = []
      @files_to_delete = []
    end

    def sort(batch_size = 100_000, &)
      create_sorted_csv_part_files(batch_size, &)
      merge_csv_part_files(&)
    end

    private

    # rubocop:disable Metrics/MethodLength
    def merge_sort_csv_files(src_csv_file1, src_csv_file2, dest_csv_file)
      src1 = CSV.open(src_csv_file1, 'rb', **csv_options)
      begin
        src2 = CSV.open(src_csv_file2, 'rb', **csv_options)
        begin
          dest = CSV.open(dest_csv_file, 'wb', **csv_options)
          begin
            if @headers
              dest << @headers
              src1.shift
              src2.shift
            end

            row1 = src1.shift
            row2 = src2.shift

            append_row1_proc = proc do
              dest << row1
              row1 = src1.shift
            end

            append_row2_proc = proc do
              dest << row2
              row2 = src2.shift
            end

            while row1 || row2
              if row1.nil?
                append_row2_proc.call
              elsif row2.nil?
                append_row1_proc.call
              elsif yield(row1, row2) <= 0
                append_row1_proc.call
              else
                append_row2_proc.call
              end
            end
          ensure
            dest.close
          end
        ensure
          src2.close
        end
      ensure
        src1.close
      end
    end
    # rubocop:enable Metrics/MethodLength

    def create_sorted_csv_part_files(batch_size, &block)
      src = CSV.open(csv_file, 'rb', **csv_options)
      begin
        @headers = src.shift if has_headers

        batch = []
        create_batch_part_proc = proc do
          batch.sort!(&block)
          @csv_part_files << "#{new_csv_file}.part.#{@csv_part_files.size}"
          CSV.open(@csv_part_files.last, 'wb', **csv_options) do |csv|
            csv << @headers if @headers
            batch.each { |row| csv << row }
          end
          batch = []
        end

        while (row = src.shift)
          batch << row
          create_batch_part_proc.call if batch.size >= batch_size
        end

        create_batch_part_proc.call if batch.size.positive?
      ensure
        src.close
      end
    end

    def merge_csv_part_files(&)
      file_merge_cnt = 0

      while @csv_part_files.size > 1
        file_merge_cnt += 1

        csv_part_file1 = @csv_part_files.shift
        csv_part_file2 = @csv_part_files.shift
        @csv_part_files << "#{new_csv_file}.merge.#{file_merge_cnt}"

        merge_sort_csv_files(csv_part_file1, csv_part_file2, @csv_part_files.last, &)

        File.unlink(csv_part_file1)
        File.unlink(csv_part_file2)
      end

      if @csv_part_files.size.positive?
        FileUtils.mv(@csv_part_files.last, new_csv_file)
      else
        FileUtils.cp(@csv_file, new_csv_file)
      end
    end
  end
end

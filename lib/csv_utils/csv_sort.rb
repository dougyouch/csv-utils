# frozen_string_literal: true

require 'fileutils'

module CSVUtils
  # Sorts a CSV file too large to load into memory with an external merge sort: batches of rows are
  # sorted into temporary part files next to the new file, which are then merged in pairs.
  #
  # @example
  #   CSVUtils::CSVSort.new('input.csv', 'sorted.csv').sort { |a, b| a[0].to_i <=> b[0].to_i }
  class CSVSort
    # @return [String] path of the file to sort
    attr_reader :csv_file
    # @return [String] path of the sorted file to write
    attr_reader :new_csv_file
    # @return [Boolean] whether the first row is a header row, kept at the top
    attr_reader :has_headers
    # @return [Hash] options passed to CSV.open
    attr_reader :csv_options
    # @return [Array<String>, nil] the header row, once {#sort} has read it
    attr_reader :headers

    # @param csv_file [String] path of the file to sort
    # @param new_csv_file [String] path of the sorted file to write
    # @param has_headers [Boolean] whether the first row is a header row
    # @param csv_options [Hash] options passed to CSV.open
    def initialize(csv_file, new_csv_file, has_headers = true, csv_options = {})
      @csv_file = csv_file
      @new_csv_file = new_csv_file
      @has_headers = has_headers
      @csv_options = csv_options
      @csv_part_files = []
    end

    # Writes the sorted file. Temporary files are removed even when sorting fails.
    # @param batch_size [Integer] rows held in memory and sorted at a time
    # @yieldparam row1 [Array<String>]
    # @yieldparam row2 [Array<String>]
    # @yieldreturn [Integer] negative, 0 or positive like <=>; without a block rows are compared as arrays
    # @return [void]
    def sort(batch_size = 100_000, &block)
      block ||= proc { |row1, row2| row1 <=> row2 }
      @csv_part_files = []
      create_sorted_csv_part_files(batch_size, &block)
      merge_csv_part_files(&block)
    ensure
      delete_csv_part_files
    end

    private

    # rubocop:disable-next Metrics/MethodLength
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

        # inputs stay in the list until merged, so a failed merge still cleans them up
        csv_part_file1, csv_part_file2 = @csv_part_files.first(2)
        @csv_part_files << "#{new_csv_file}.merge.#{file_merge_cnt}"

        merge_sort_csv_files(csv_part_file1, csv_part_file2, @csv_part_files.last, &)

        @csv_part_files.shift(2).each { |file| File.unlink(file) }
      end

      if @csv_part_files.size.positive?
        FileUtils.mv(@csv_part_files.pop, new_csv_file)
      else
        FileUtils.cp(@csv_file, new_csv_file)
      end
    end

    # removes the temporary files left behind when sorting fails part way through
    def delete_csv_part_files
      @csv_part_files.each { |file| FileUtils.rm_f(file) }
      @csv_part_files = []
    end
  end
end

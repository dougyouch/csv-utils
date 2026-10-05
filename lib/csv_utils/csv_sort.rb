# frozen_string_literal: true

require 'fileutils'

module CSVUtils
  # Sorts a CSV file too large to load into memory with an external merge sort: batches of rows are
  # sorted into temporary files, which are then merged up to {MERGE_WIDTH} at a time, so most files
  # are sorted with a single merge pass.
  #
  # @example
  #   CSVUtils::CSVSort.new('input.csv', 'sorted.csv').sort { |a, b| a[0].to_i <=> b[0].to_i }
  #   CSVUtils::CSVSort.new('input.csv', 'sorted.csv').sort_by { |row| row[0].to_i }
  class CSVSort
    # @return [Integer] temporary files merged at once, which bounds the files open at the same time
    MERGE_WIDTH = 64

    ROW_KEY = proc { |row| row }
    KEY_COMPARE = proc { |key1, key2| key1 <=> key2 }
    private_constant :ROW_KEY, :KEY_COMPARE

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
    # @param csv_options [Hash] options passed to CSV.open; the file is read with its :encoding, 'bom|utf-8' by
    #   default, and the sorted file written in the encoding values were decoded to (see {EncodingOptions})
    def initialize(csv_file, new_csv_file, has_headers = true, csv_options = {})
      @csv_file = csv_file
      @new_csv_file = new_csv_file
      @has_headers = has_headers
      @csv_options = csv_options
      @temp_files = []
    end

    # Writes the file sorted by comparing rows. Temporary files are removed even when sorting fails.
    # @param batch_size [Integer] rows held in memory and sorted at a time
    # @param tmp_dir [String, nil] directory for the temporary files; the sorted file's directory by default
    # @yieldparam row1 [Array<String>]
    # @yieldparam row2 [Array<String>]
    # @yieldreturn [Integer] negative, 0 or positive like <=>; without a block rows are compared as arrays
    # @return [void]
    def sort(batch_size = 100_000, tmp_dir: nil, &block)
      compare = block || KEY_COMPARE
      run_sort(batch_size, tmp_dir, ROW_KEY, compare) { |batch| batch.sort!(&compare) }
    end

    # Writes the file sorted by a key computed once per row, which is faster than {#sort} when
    # the comparison would otherwise convert values (ex: to_i) on every comparison.
    # @param batch_size [Integer] rows held in memory and sorted at a time
    # @param tmp_dir [String, nil] directory for the temporary files; the sorted file's directory by default
    # @yieldparam row [Array<String>]
    # @yieldreturn [Comparable] the sort key; keys are compared with <=>, so use arrays for several columns
    # @return [void]
    def sort_by(batch_size = 100_000, tmp_dir: nil, &key)
      run_sort(batch_size, tmp_dir, key, KEY_COMPARE) { |batch| batch.sort_by!(&key) }
    end

    private

    def run_sort(batch_size, tmp_dir, key, compare, &)
      @tmp_dir = tmp_dir || File.dirname(new_csv_file)
      @temp_files = []
      part_files = create_sorted_part_files(batch_size, &)
      part_files = merge_pass(part_files, key, compare) while part_files.size > 1
      write_sorted_file(part_files.first)
    ensure
      delete_temp_files
    end

    def create_sorted_part_files(batch_size, &sort_batch)
      CSV.open(csv_file, 'rb', **EncodingOptions.read(csv_options)) do |src|
        @headers = (src.shift if has_headers)
        src.each_slice(batch_size).map do |batch|
          sorted = sort_batch.call(batch)
          write_temp_file { |csv| sorted.each { |row| csv << row } }
        end
      end
    end

    # merges consecutive groups of files, so each pass divides the number of files by MERGE_WIDTH
    def merge_pass(files, key, compare)
      files.each_slice(MERGE_WIDTH).map do |group|
        next group.first if group.size == 1

        merged = write_temp_file { |dest| merge_files(group, dest, key, compare) }
        group.each { |file| File.unlink(file) }
        merged
      end
    end

    # keeps the next row of every file in a queue sorted by key, so each row written is the smallest left
    def merge_files(files, dest, key, compare)
      open_temp_files(files) do |sources|
        queue = []
        sources.each_with_index do |src, idx|
          src.shift if @headers
          enqueue(queue, src.shift, idx, key, compare)
        end

        until queue.empty?
          _, row, idx = queue.shift
          dest << row
          enqueue(queue, sources[idx].shift, idx, key, compare)
        end
      end
    end

    # rows with equal keys keep the order of the files they came from
    def enqueue(queue, row, idx, key, compare)
      return unless row

      value = key.call(row)
      pos = queue.bsearch_index do |other_value, _, other_idx|
        result = compare.call(value, other_value)
        result.negative? || (result.zero? && idx < other_idx)
      end
      queue.insert(pos || queue.size, [value, row, idx])
    end

    def open_temp_files(files)
      sources = []
      # not map: sources has to hold the files opened before one fails to open, so ensure closes them
      # rubocop:disable-next Style/MapIntoArray
      files.each { |file| sources << CSV.open(file, 'rb', **write_options) }
      yield sources
    ensure
      sources.each(&:close)
    end

    # temporary files are written with the write options, so reading them back with those changes nothing
    def write_temp_file
      @temp_files << File.join(@tmp_dir, "#{File.basename(new_csv_file)}.#{@temp_files.size}.tmp")
      CSV.open(@temp_files.last, 'wb', **write_options) do |csv|
        csv << @headers if @headers
        yield csv
      end
      @temp_files.last
    end

    # a file without rows is written rather than copied, so it's in the same encoding as a sorted one
    def write_sorted_file(sorted_file)
      return FileUtils.mv(sorted_file, new_csv_file) if sorted_file

      CSV.open(new_csv_file, 'wb', **write_options) do |csv|
        csv << @headers if @headers
      end
    end

    def write_options
      EncodingOptions.write(csv_options)
    end

    # removes the temporary files left behind when sorting fails part way through
    def delete_temp_files
      @temp_files.each { |file| FileUtils.rm_f(file) }
      @temp_files = []
    end
  end
end

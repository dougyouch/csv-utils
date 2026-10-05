# frozen_string_literal: true

module CSVUtils
  # Copies a CSV file through a pipeline of steps that filter, change and add to its rows in batches.
  # Each step method returns the transformer so they can be chained, and {#process} runs them.
  #
  # Step blocks receive the row, the headers as they were when the step was added, and the value
  # computed by the last {#additional_data} step for the current batch.
  #
  # @example
  #   CSVUtils::CSVTransformer.new('input.csv', 'output.csv')
  #     .read_headers
  #     .select { |row, _headers, _data| row[0].to_i > 100 }
  #     .append(['Email']) { |row, _headers, _data| ["#{row[1].downcase}@example.com"] }
  #     .process
  class CSVTransformer
    # @return [Array<String>, nil] the headers the output will have after the steps added so far
    attr_reader :headers

    # @param src_csv [String, CSV, #shift] path or CSV to read; paths are opened and closed by the transformer
    # @param dest_csv [String, CSV, #<<] path or CSV to write
    # @param csv_options [Hash] options passed to CSV.open for paths; the source is read with its :encoding,
    #   'bom|utf-8' by default, and the output written in the encoding values were decoded to (see {EncodingOptions})
    def initialize(src_csv, dest_csv, csv_options = {})
      @src_csv = CSVUtils::CSVWrapper.new(src_csv, 'rb', EncodingOptions.read(csv_options))
      @dest_csv = CSVUtils::CSVWrapper.new(dest_csv, 'wb', EncodingOptions.write(csv_options))
    end

    # Reads the first row as the headers. Without it, every row is data and the output has no header row.
    # @return [self]
    def read_headers
      @headers = @src_csv.shift
      self
    end

    # Computes a value once per batch, passed to the steps that follow as their third argument.
    # @yieldparam batch [Array<Array<String>>]
    # @yieldparam headers [Array<String>, nil]
    # @return [self]
    def additional_data(&block)
      steps << [:additional_data, @headers, block]
      self
    end

    # Keeps the rows the block returns true for.
    # @yieldparam row [Array<String>]
    # @yieldparam headers [Array<String>, nil]
    # @yieldparam additional_data [Object]
    # @return [self]
    def select(&block)
      steps << [:select, @headers, block]
      self
    end

    # Drops the rows the block returns true for.
    # @yieldparam (see #select)
    # @return [self]
    def reject(&block)
      steps << [:reject, @headers, block]
      self
    end

    # Replaces each row with the block's result.
    # @param new_headers [Array<String>, nil] the headers after this step
    # @yieldparam (see #select)
    # @yieldreturn [Array] the new row
    # @return [self]
    def map(new_headers, &block)
      steps << [:map, @headers, block]
      @headers = new_headers
      self
    end

    # Adds the block's values to the end of each row.
    # @param additional_headers [Array<String>, nil] headers for the new values; nil drops the header row
    # @yieldparam (see #select)
    # @yieldreturn [Array] values to append
    # @return [self]
    def append(additional_headers, &block)
      steps << [:append, @headers, block]
      # without headers (read_headers not called) the output has no header row to extend
      @headers = (@headers + additional_headers if @headers && additional_headers)
      self
    end

    # Calls the block for each row without changing it.
    # @yieldparam (see #select)
    # @return [self]
    def each(&block)
      steps << [:each, @headers, block]
      self
    end

    # Replaces the headers written to the output.
    # @param headers [Array<String>, nil]
    # @return [self]
    def set_headers(headers)
      @headers = headers
      self
    end

    # Runs the steps over every row, writes the output and closes the files it opened, even when a step raises.
    # @param batch_size [Integer] rows read and run through the steps at a time
    # @return [void]
    def process(batch_size = 10_000)
      batch = []

      @dest_csv << @headers if @headers

      steps_proc = proc do
        steps.each do |step_type, current_headers, proc|
          batch = process_step(step_type, current_headers, batch, &proc)
        end

        batch.each { |row| @dest_csv << row }

        batch = []
      end

      while (row = @src_csv.shift)
        batch << row
        steps_proc.call if batch.size >= batch_size
      end

      steps_proc.call if batch.size.positive?
    ensure
      @src_csv.close
      @dest_csv.close
    end

    private

    def steps
      @steps ||= []
    end

    # each step type has a process_<type>_step method that changes the batch in place
    def process_step(step_type, current_headers, batch, &)
      send(:"process_#{step_type}_step", current_headers, batch, &)
      batch
    end

    def process_select_step(current_headers, batch)
      batch.select! { |row| yield row, current_headers, @additional_data }
    end

    def process_reject_step(current_headers, batch)
      batch.reject! { |row| yield row, current_headers, @additional_data }
    end

    def process_map_step(current_headers, batch)
      batch.map! { |row| yield row, current_headers, @additional_data }
    end

    def process_append_step(current_headers, batch)
      batch.map! { |row| row + yield(row, current_headers, @additional_data) }
    end

    def process_additional_data_step(current_headers, batch)
      @additional_data = yield batch, current_headers
    end

    def process_each_step(current_headers, batch)
      batch.each { |row| yield row, current_headers, @additional_data }
    end
  end
end

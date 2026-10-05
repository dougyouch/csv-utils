# frozen_string_literal: true

# Transforms a CSV given a series of steps
module CSVUtils
  class CSVTransformer
    attr_reader :headers

    def initialize(src_csv, dest_csv, csv_options = {})
      @src_csv = CSVUtils::CSVWrapper.new(src_csv, 'rb', csv_options)
      @dest_csv = CSVUtils::CSVWrapper.new(dest_csv, 'wb', csv_options)
    end

    def read_headers
      @headers = @src_csv.shift
      self
    end

    def additional_data(&block)
      steps << [:additional_data, @headers, block]
      self
    end

    def select(&block)
      steps << [:select, @headers, block]
      self
    end

    def reject(&block)
      steps << [:reject, @headers, block]
      self
    end

    def map(new_headers, &block)
      steps << [:map, @headers, block]
      @headers = new_headers
      self
    end

    def append(additional_headers, &block)
      steps << [:append, @headers, block]
      # without headers (read_headers not called) the output has no header row to extend
      @headers = (@headers + additional_headers if @headers && additional_headers)
      self
    end

    def each(&block)
      steps << [:each, @headers, block]
      self
    end

    def set_headers(headers)
      @headers = headers
      self
    end

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

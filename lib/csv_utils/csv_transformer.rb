# Transforms a CSV given a series of steps
class CSVUtils::CSVTransformer
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

    if additional_headers
      @headers += additional_headers
    else
      @headers = nil
    end

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

  def process(batch_size = 10_000, &block)
    batch = []

    @dest_csv << @headers if @headers

    steps_proc = Proc.new do
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

    steps_proc.call if batch.size > 0

    @src_csv.close
    @dest_csv.close
  end

  private

  def steps
    @steps ||= []
  end


  def process_step(step_type, current_headers, batch, &block)
    case step_type
    when :select
      batch.select! do |row|
        block.call row, current_headers, @additional_data
      end
    when :reject
      batch.reject! do |row|
        block.call row, current_headers, @additional_data
      end
    when :map
      batch.map! do |row|
        block.call row, current_headers, @additional_data
      end
    when :append
      batch.map! do |row|
        row + block.call(row, current_headers, @additional_data)
      end
    when :additional_data
      @additional_data = block.call(batch, current_headers)
    when :each
      batch.each do |row|
        block.call(row, current_headers, @additional_data)
      end
    end

    batch
  end
end

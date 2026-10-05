# frozen_string_literal: true

# Times the streaming classes and counts the objects they allocate, to catch speed and memory regressions.
#
#   ruby script/benchmark.rb               # 200,000 rows
#   ROWS=1000000 ruby script/benchmark.rb
#   LIB=/path/to/other/checkout/lib ruby script/benchmark.rb   # compare against another version

$LOAD_PATH.unshift(ENV.fetch('LIB', File.expand_path('../lib', __dir__)))
require 'csv-utils'
require 'csv_utils/version'
require 'tmpdir'

ROWS = Integer(ENV.fetch('ROWS', 200_000))
COLUMNS = 20
BATCH_SIZE = Integer(ENV.fetch('BATCH_SIZE', 10_000))

def generate(path, rows, offset = 0)
  CSV.open(path, 'wb') do |csv|
    csv << (1..COLUMNS).map { |col| "header_#{col}" }
    rows.times do |row|
      id = ((row * 7_919) + offset) % rows
      csv << [id, *(2..COLUMNS).map { |col| "value #{id} #{col}" }]
    end
  end
end

def measure(label)
  GC.start
  objects = GC.stat(:total_allocated_objects)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  allocated = GC.stat(:total_allocated_objects) - objects
  printf("%-34s %8.2fs %10.1fM objects\n", label, seconds, allocated / 1e6)
end

Dir.mktmpdir do |dir|
  src = File.join(dir, 'src.csv')
  other = File.join(dir, 'other.csv')
  sorted = File.join(dir, 'sorted.csv')
  sorted_other = File.join(dir, 'sorted_other.csv')
  generate(src, ROWS)
  generate(other, ROWS, 3)

  puts "csv-utils #{CSVUtils::VERSION}, #{ROWS} rows x #{COLUMNS} columns, sort batch #{BATCH_SIZE}, ruby #{RUBY_VERSION}"
  measure('CSV#shift (baseline)') { CSV.open(src, 'rb') { |csv| nil while csv.shift } }
  measure('CSVIterator#each') { CSVUtils::CSVIterator.new(src).each { |_| nil } }

  sorter = CSVUtils::CSVSort.new(src, sorted)
  measure('CSVSort#sort') { sorter.sort(BATCH_SIZE) { |a, b| a[0].to_i <=> b[0].to_i } }
  measure('CSVSort#sort_by') { sorter.sort_by(BATCH_SIZE) { |row| row[0].to_i } } if sorter.respond_to?(:sort_by)

  CSVUtils::CSVSort.new(other, sorted_other).sort(BATCH_SIZE) { |a, b| a[0].to_i <=> b[0].to_i }
  compare = CSVUtils::CSVCompare.new(sorted, ['header_2']) { |a, b| a['header_1'].to_i <=> b['header_1'].to_i }
  measure('CSVCompare#compare') { compare.compare(sorted_other) { |_action, _record| nil } }
end

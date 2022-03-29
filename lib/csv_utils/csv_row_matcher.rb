module CSVUtils
  class CSVRowMatcher
    attr_accessor :regex,
                  :columns

    def initialize(regex, columns = :all)
      self.regex = regex
      self.columns = columns
    end

    def match?(row)
      if columns == :all
        row.each_value do |value|
          return true if value && value.match?(regex)
        end
      else
        columns.each do |column_name|
          value = row[column_name]
          return true if value && value.match?(regex)
        end
      end

      false
    end

    def to_proc
      Proc.new do |row|
        match?(row)
      end
    end
  end
end

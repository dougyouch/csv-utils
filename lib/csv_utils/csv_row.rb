module CSVUtils
  module CSVRow
    def self.included(base)
      base.extend InheritanceHelper::Methods
      base.extend ClassMethods
    end

    module ClassMethods
      def csv_columns
        {}
      end

      def csv_column(header, options = {}, &block)
        options[:header] ||= header.to_s

        if block
          options[:proc] = block
        elsif options[:proc].nil?
          options[:method] ||= header
        end

        add_value_to_class_method(:csv_columns, header => options)
      end
    end

    def csv_headers
      self.class.csv_columns.values.map { |column_options| csv_column_header(column_options) }
    end

    def csv_row
      self.class.csv_columns.values.map { |column_options| csv_column_value(column_options) }
    end

    private

    def csv_column_header(column_options)
      column_options[:header]
    end

    def csv_column_value(column_options)
      if column_options[:proc]
        instance_eval(&column_options[:proc])
      else
        send(column_options[:method])
      end
    end
  end
end

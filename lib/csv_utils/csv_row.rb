# frozen_string_literal: true

require 'inheritance-helper'

module CSVUtils
  # Mixin that declares how an object turns into a CSV row, for use with {CSVReport}.
  # Columns are inherited by subclasses.
  #
  # @example
  #   class UserCSVRow < User
  #     include CSVUtils::CSVRow
  #
  #     csv_column :id, header: 'ID'
  #     csv_column :name
  #     csv_column(:email) { email.downcase }
  #   end
  module CSVRow
    # @api private
    # @param base [Class]
    # @return [void]
    def self.included(base)
      base.extend InheritanceHelper::Methods
      base.extend ClassMethods
    end

    # Class level DSL for declaring columns.
    module ClassMethods
      # Declared columns, keyed by name, in declaration order.
      # @return [Hash{Symbol => Hash}]
      def csv_columns
        {}
      end

      # Declares a column.
      # @param header [Symbol, String] column name; also the default header and the method that provides the value
      # @param options [Hash]
      # @option options [String] :header header text
      # @option options [Symbol] :method method that provides the value
      # @option options [Proc] :proc evaluated on the object to provide the value
      # @yield evaluated on the object to provide the value, like :proc
      # @return [void]
      def csv_column(header, options = {}, &block)
        options = options.dup
        options[:header] ||= header.to_s

        if block
          options[:proc] = block
        elsif options[:proc].nil?
          options[:method] ||= header
        end

        add_value_to_class_method(:csv_columns, header => options)
      end

      # @return [Array<String>] the header of each column
      def csv_headers
        csv_columns.values.map { |column_options| csv_column_header(column_options) }
      end

      private

      def csv_column_header(column_options)
        column_options[:header]
      end
    end

    # The value of each column.
    # @return [Array]
    def csv_row
      self.class.csv_columns.values.map { |column_options| csv_column_value(column_options) }
    end
    alias to_a csv_row

    # @return [Array<String>] the header of each column
    def csv_headers
      self.class.csv_headers
    end

    private

    def csv_column_value(column_options)
      if column_options[:proc]
        instance_eval(&column_options[:proc])
      else
        send(column_options[:method])
      end
    end
  end
end

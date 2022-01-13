# frozen_string_literal: true

require 'csv'

module EmEasyScraper
  module Plugin
    module CsvContentHandler
      module ClassMethods
      end

      def self.prepended(base)
        class << base
          prepend ClassMethods
        end
      end

      def parse(task)
        results = super
        validate_results(results)
        if results.any?
          unless File.exist?(result_file_path)
            shop_folder_path = File.dirname(result_file_path)
            FileUtils.mkdir_p(shop_folder_path)
            FileUtils.touch(result_file_path)
          end
          headers = csv_headers || results.first.keys
          CSV.open(result_file_path, 'a+', write_headers: File.zero?(result_file_path), headers: headers) do |csv|
            results.each do |result|
              csv << headers.map { |key| result[key] }
            end
          end
        end
        results
      end

      private

      def validate_results(_results)
        raise NotImplementedError unless defined?(super)
      end

      def csv_headers
        raise NotImplementedError unless defined?(super)
      end

      def result_file_path
        raise NotImplementedError unless defined?(super)
      end
    end
  end
end

# frozen_string_literal: true

module EmEasyScraper
  module Helper
    class RotationManager
      attr_accessor :data

      def initialize(provider, raw_data)
        @provider = provider
        @data = []
        initialize_data(raw_data)
      end

      def initialize_data(raw_data)
        raw_data.each { |element| push(element) }
        data.sort_by! do |element|
          element[:ban_time] = cache.read(element[:element], namespace: cache_namespace)
          element[:ban_time].to_i
        end
      end

      def pop
        element = data.shift
        raise(EmEasyScraper::HelperError, "#{self.class}: Element not found") unless element
        raise(EmEasyScraper::HelperError, "#{self.class}: All elements were banned") if banned?(element)

        element[:element]
      end

      def push(element, ban_time: nil)
        data_info = { element: element }
        if ban_time
          banned_up_to = Time.now.to_i + ban_time
          data_info[:ban_time] = banned_up_to
          cache.write(element, banned_up_to, expires_in: ban_time, namespace: cache_namespace)
        end

        data.push(data_info)
      end

      def insert(element)
        data.insert(0, element: element)
      end

      def banned?(element)
        element[:ban_time] && element[:ban_time] >= Time.now.to_i
      end

      protected

      def cache_namespace
        [
          'ees',
          self.class.name.split('::').last.underscore,
          @provider.class.name.split('::').last.underscore
        ].join(':')
      end

      def cache
        @provider.cache
      end
    end
  end
end

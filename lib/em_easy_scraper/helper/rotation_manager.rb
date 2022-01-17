# frozen_string_literal: true

module EmEasyScraper
  module Helper
    class RotationManager
      include Singleton

      REQUIRED_PARAMS = %i[cache namespace data].freeze
      attr_accessor :data

      @opts = nil

      def self.opts=(opts)
        REQUIRED_PARAMS.each do |required_param|
          raise(EmEasyScraper::HelperError, "#{required_param} is empty") unless opts.key?(required_param)
        end
        @opts = opts
      end

      class << self
        attr_reader :opts
      end

      def initialize
        initialize_data(self.class.opts)
      end

      def initialize_data(opts)
        @data = []
        @cache = opts[:cache]
        opts[:data].each { |element| push(element) }
        @data.sort_by! do |element|
          element[:ban_time] = @cache.read(element[:element], namespace: cache_namespace)
          element[:ban_time].to_i
        end
      end

      def pop
        element = @data.shift
        raise(EmEasyScraper::HelperError, "#{self.class}: Element not found") unless element
        raise(EmEasyScraper::HelperError, "#{self.class}: All elements were banned") if banned?(element)

        element[:element]
      end

      def push(element, ban_time: nil)
        data_info = { element: element }
        if ban_time
          banned_up_to = Time.now.to_i + ban_time
          data_info[:ban_time] = banned_up_to
          @cache.write(element, ban_time, expires_in: ban_time, namespace: cache_namespace)
        end

        @data.push(data_info)
      end

      def banned?(element)
        element[:ban_time] && element[:ban_time] >= Time.now.to_i
      end

      protected

      def cache_namespace
        'rotation_manager'
      end
    end
  end
end

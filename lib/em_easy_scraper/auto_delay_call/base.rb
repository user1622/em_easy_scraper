# frozen_string_literal: true

module EmEasyScraper
  module AutoDelayCall
    class Base
      CACHE_NAMESPACE = 'auto_delay_call'

      attr_reader :normal_delay

      def initialize(actions_per_period:, period: 1.second.to_f)
        @actions_per_period = actions_per_period
        @period = period
        @normal_delay = period.to_f / @actions_per_period
      end

      def execute(key, work: nil, reject: nil, on_error: nil, &block)
        PromiseEm::Promise.new { |resolve, _reject| resolve.call }
                          .then { calculate_delay(key) }
                          .then { |delay| delay.zero? ? (block || work).call : reject&.call(delay) }
                          .catch { |error| on_error&.call(error) }
      end

      private

      def calculate_delay(key)
        raise NotImplementedError
      end

      def history_key(key)
        [CACHE_NAMESPACE, key, @actions_per_period, @period].map(&:to_s).join(':')
      end

      def state_ok?(state)
        state[:status] == STATUS[:OK]
      end
    end
  end
end
